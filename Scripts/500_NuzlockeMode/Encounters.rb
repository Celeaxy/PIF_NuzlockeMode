=begin
  TODO:
  - Webs, mushrooms
=end

module NuzlockeMode
  class << self
    attr_accessor :encounters
    attr_accessor :ballsReceived
  end

  def self.ballsReceived?
    self.ballsReceived.to_s == 'true'
  end

  def self.hadEncounter?(enc_type = nil)
    encounter_type = enc_type || $PokemonEncounters.encounter_type
    self.encounters.include?([$game_map.map_id, nuzlockeMode_generalize_enc_type(encounter_type)])
  end

  def self.registerEncounter(enc_type = nil)
    encounter_type = enc_type || $PokemonEncounters.encounter_type
    self.encounters.push([$game_map.map_id, nuzlockeMode_generalize_enc_type(encounter_type)])
    #pbMessage(_INTL("Registered encounters: {1}", self.encounters))
  end
end

class PokemonBag
  def nuzlockeMode_hasBalls?
    $BallTypes.any? { |(k, ball)| pbHasItem?(ball) }
  end
end

SaveData.register(:nuzlockeMode_encounters) do
  save_value { NuzlockeMode.encounters }
  load_value { |value| NuzlockeMode.encounters = value }
  new_game_value { [] }
end

SaveData.register(:nuzlockeMode_ballsReceived) do
  save_value { NuzlockeMode.ballsReceived? }
  load_value { |value| NuzlockeMode.ballsReceived = value }
  new_game_value { false }
end


class PokemonEncounters
  attr_reader :encounter_tables

  alias_method :original_setup, :setup
  def setup(map_ID)
    original_setup(map_ID)

    if NuzlockeMode.active?
      @map_ID = map_ID
      had_enc = @encounter_tables.length > 0
      @encounter_tables = nuzlockeMode_getUncaughtEncounters().select { |k,v| !v.empty?}
      message = encounterMessage
      # Don't show message if already encountered a pokemon
      pbMessage(_INTL(message)) if had_enc && message != "" && !NuzlockeMode.encounters.any? {|enc| enc[0] == map_ID}
    end
  end

  def nuzlockeMode_getUncaughtEncounters 
    Hash[@encounter_tables.map { |enc_type, enc_list| [enc_type, enc_list.select { |enc| !$Trainer.nuzlockeMode_hasPokemon?(enc[1])}]}]   
  end

  alias_method :original_encounter_possible_here?, :encounter_possible_here?
  def encounter_possible_here?
    if NuzlockeMode.active?
      if !NuzlockeMode.ballsReceived? && $PokemonBag.nuzlockeMode_hasBalls?
        NuzlockeMode.ballsReceived = true
        pbMessage("Encounters activated")
      end
      return false if !NuzlockeMode.ballsReceived?
    end
    original_encounter_possible_here?
  end

  # Returns whether an encounter with the given Pokémon should be allowed after
  # taking into account Repels and ability effects.
  # if encounter is allowed, a battle is started in pbBattleOnStepTaken
  alias_method :original_allow_encounter?, :allow_encounter?
  def allow_encounter?(enc_data, repel_active = false)
    ret = original_allow_encounter?(enc_data, repel_active)
    if ret && NuzlockeMode.active?
      if !NuzlockeMode.hadEncounter? && !$Trainer.nuzlockeMode_hasPokemon?(enc_data[1])
        NuzlockeMode.registerEncounter
      else
        return false
      end
    end
    ret
  end
end

def nuzlockeMode_generalize_enc_type(enc_type)
  if enc_type.match(/^L/) # Land, LandDay, LandNight, LandMorning, LandAfternoon, LandEvening
    return "Land"
  elsif enc_type.match(/^C/) # Cave, CaveDay, CaveNight, CaveMorning, CaveAfternoon, CaveEvening
    return "Cave"
  elsif enc_type.match(/^W/) # Water, WaterDay, WaterNight, WaterMorning, WaterAfternoon, WaterEvening
    return "Water"
  elsif enc_type.match(/Rod$/) # OldRod, GoodRod, SuperRod
    return "Rod"
  elsif enc_type.match(/^H/) # HeadbuttLow, HeadbutHigh
    return "Headbutt"
  elsif enc_type.match(/^R/) # RockSmash
    return "RockSmash"
  elsif enc_type.match(/^B/) # BugContest
    return "BugContest"
  end

  return enc_type # ???
end

def toReadable(enc_tables)
  Hash[enc_tables.map {|enc_type,enc_list| [enc_type, enc_list.map { |enc| getSpecies(enc[1]).name }]}]
end

def encounterMessage
  message = "Encounters only"
  case $PokemonEncounters.encounter_tables.select {|t, l| l.length > 0}.length
  when 0 
    return "No new encounters on this route."
  when 1
    enc_type = $PokemonEncounters.encounter_tables.map { |k, v| k }[0]
    case nuzlockeMode_generalize_enc_type(enc_type)
    when "Land"
      message += " on land"
    when "Cave"
      message += " in a cave"
    when "Water"
      message += " in a cave"
    when "Rod"
      message " by fishing"
    when "Headbutt"
      message += " with Headbutt"
    when "RockSmash"
      message += " with Rock Smash"
    when "BugContest"
      return ""
    end

    if enc_type.match(/Day$/)
      message += " at day"
    elsif enc_type.match(/Morning$/)
      message += " in the morning"
    elsif enc_type.match(/Night$/)
      message += " at night"
    elsif enc_type.match(/Afternoon$/)
      message += " in the afternoon"
    elsif enc_type.match(/Evening$/)
      message += " in the evening"
    end
  end
  if message != "Encounters only"
    return message + "."
  end
  ""
end

def flatEncountertables
  ret = {}
  $PokemonEncounters.encounter_tables.each {
    |enc_type, enc_list|
    genEncType = nuzlockeMode_generalize_enc_type(enc_type)
    if !ret[genEncType]
      ret[genEncType] = []
    end
    ret[genEncType] += enc_list
  }
  ret
end

class Player
  def nuzlockeMode_availablePokemon()
    @party.select {|p| !p.fainted?} + $PokemonStorage.boxes.flat_map { |box| box.pokemon.select { |p| p != nil && !p.fainted?} }
  end

  def nuzlockeMode_hasPokemon?(pkmn)
    if(!species_is_fusion(pkmn))
      pkmn = getRandomizedTo(pkmn)
    end
    headId = getHeadID(pkmn)
    bodyId = species_is_fusion(pkmn) ? getBodyID(pkmn) : nil

    head = headId ? GameData::Species.get(headId).get_baby_species : nil
    body = bodyId ? GameData::Species.get(bodyId).get_baby_species : nil
    
    avPkmn = nuzlockeMode_availablePokemon().flat_map { |p| 
      pHeadId = getHeadID(p)
      pBodyId = species_is_fusion(p.species) ? getBodyID(p) : nil
      [pHeadId ? GameData::Species.get(pHeadId).get_baby_species : nil, 
       pBodyId ? GameData::Species.get(pBodyId).get_baby_species : nil]
    }.select {|p| p != nil}
    #pbMessage(_INTL("{1}", avPkmn))
    return avPkmn.any? {|p| head == p || body == p}
  end
end



alias :original_pbDefaultRockSmashEncounter :pbDefaultRockSmashEncounter
def pbDefaultRockSmashEncounter(minLevel,maxLevel)
  pkmn = getRandomizedTo(:GEODUDE)
  if NuzlockeMode.active?
    return false if NuzlockeMode.hadEncounter?(:RockSmash) || $Trainer.nuzlockeMode_hasPokemon?(pkmn)
  end
  ret = original_pbDefaultRockSmashEncounter(minLevel, maxLevel)
  if NuzlockeMode.active?
    NuzlockeMode.registerEncounter(:RockSmash)
  end
  ret
end

# Used by fishing rods and Headbutt/Rock Smash/Sweet Scent to generate a wild
# Pokémon (or two) for a triggered wild encounter.
def pbEncounter(enc_type)
  $PokemonTemp.encounterType = enc_type
  encounter1 = $PokemonEncounters.choose_wild_pokemon(enc_type)
  encounter1 = EncounterModifier.trigger(encounter1)

  return false if !encounter1
  return false if NuzlockeMode.active? && (NuzlockeMode.hadEncounter?(enc_type) || $Trainer.nuzlockeMode_hasPokemon?(encounter1[0]))
  if $PokemonEncounters.have_double_wild_battle?
    encounter2 = $PokemonEncounters.choose_wild_pokemon(enc_type)
    encounter2 = EncounterModifier.trigger(encounter2)
    return false if !encounter2
    return false if NuzlockeMode.active? && (NuzlockeMode.hadEncounter?(enc_type) || $Trainer.nuzlockeMode_hasPokemon?(encounter2[0]))
    pbDoubleWildBattle(encounter1[0], encounter1[1], encounter2[0], encounter2[1])
  else
    pbWildBattle(encounter1[0], encounter1[1])
  end
	$PokemonTemp.encounterType = nil
  $PokemonTemp.forceSingleBattle = false
  EncounterModifier.triggerEncounterEnd
  NuzlockeMode.registerEncounter(enc_type)
  return true
end