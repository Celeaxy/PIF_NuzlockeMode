# ----------------------------------------------------------------------------------------------------
# TODO:
#   - Static encounters like Voltorbs etc.
# ----------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------
# NuzlockeMode encounter module
# ----------------------------------------------------------------------------------------------------

module NuzlockeMode
  class << self
    attr_accessor :encounters
    attr_accessor :ballsReceived
  end

  def self.ballsReceived?
    self.ballsReceived ||= $PokemonBag.nuzlockeMode_hasBalls?
  end

  def self.updateEncounterType(enc_type = nil)
    @encounterType = enc_type || $PokemonEncounters.encounter_type
  end

  def self.encounterType
    @encounterType
  end
  def self.resetEncounterType
    @encounterType = nil
  end

  def self.preventEncounter?(enc_type = nil)
    return false if !NuzlockeMode.active?
    self.hadEncounter?(enc_type)
  end

  def self.hadEncounter?(enc_type = nil)
    encounter_type = enc_type || self.encounterType || $PokemonEncounters.encounter_type
    self.encounters.include?([$game_map.map_id, nuzlockeMode_generalize_enc_type(encounter_type)])
  end

  def self.registerEncounter(enc_type = nil)
    return if !NuzlockeMode.active?
    encounter_type = enc_type || self.encounterType
    self.encounters.push([$game_map.map_id, nuzlockeMode_generalize_enc_type(encounter_type)])
  end
end


# ----------------------------------------------------------------------------------------------------
# Data persistance
# ----------------------------------------------------------------------------------------------------

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
  alias_method :original_setup, :setup
  def setup(map_ID)
    original_setup(map_ID)
    nuzlockeMode_updateEncounterTables
    # pbMessage(_INTL("{1}", map_ID))
  end

  def nuzlockeMode_getEncounterTypes
    @encounter_tables.map {|k,v| k}
  end

  def nuzlockeMode_updateEncounterTables
    return if !NuzlockeMode.active?
    @encounter_tables =  @encounter_tables.select{ |enc_type, enc_list| !NuzlockeMode.preventEncounter?(enc_type)}
  end


  # Prevent encounters before having balls
  alias_method :original_encounter_possible_here?, :encounter_possible_here?
  def encounter_possible_here?
    return false if NuzlockeMode.active? && !NuzlockeMode.ballsReceived?
    original_encounter_possible_here?
  end

  # Register encounter after allowing it, since this triggers an encounter in pbBattleOnStepTaken
  alias_method :original_allow_encounter?, :allow_encounter?
  def allow_encounter?(enc_data, repel_active = false)
    NuzlockeMode.updateEncounterType
    return !NuzlockeMode.preventEncounter? && original_allow_encounter?(enc_data, repel_active) 
  end
end


# ----------------------------------------------------------------------------------------------------
# Hooks to register and prevent encounters
# ----------------------------------------------------------------------------------------------------

alias :original_pbDefaultRockSmashEncounter :pbDefaultRockSmashEncounter
def pbDefaultRockSmashEncounter(minLevel,maxLevel)
  NuzlockeMode.updateEncounterType(:RockSmash)
  return !NuzlockeMode.preventEncounter? && original_pbDefaultRockSmashEncounter(minLevel, maxLevel)
end

alias :original_pbEncounter :pbEncounter
def pbEncounter(enc_type)
  NuzlockeMode.updateEncounterType(enc_type)
  return !NuzlockeMode.preventEncounter? && original_pbEncounter(enc_type)
end


# ----------------------------------------------------------------------------------------------------
# Display remaining encounters in pause menu [WIP]
# ----------------------------------------------------------------------------------------------------

class EncounterWindow < SpriteWindow_Base
  def initialize(enc_types, viewport = nil)
    height = 0
    width = 0
    padding = 2
    if enc_types && enc_types.length > 0
      height = 64
      width = 32*(enc_types.length+1) + padding*(enc_types.length-1)
    end
    super(0,0,width,height)
    @viewport = viewport

    bitmap_pos = {
      "Land" => 0,
      "Water" => 1,
      "Cave" => 2,
      "Rod" => 3,
      "RockSmash" => 4,
      "Headbutt" => 5
    }
    
    content_w = 32+32*enc_types.length + padding*(enc_types.length-1)
    @contents = Bitmap.new(content_w, 32)
    enc_bitmap = Bitmap.new(_INTL("Data/NuzlockeMode_Data/encounters"))

    for i in 0..enc_types.length
      pos = bitmap_pos[enc_types[i]]
      if pos
        rect = Rect.new(0,pos*32,32,32)
        self.contents.blt(i*(32+padding), 0, enc_bitmap, rect)
      end
    end
  end
end

class PokemonPauseMenu_Scene 
  alias_method :original_pbStartScene, :pbStartScene
  def pbStartScene
    original_pbStartScene
    nuzlockeMode_createEncounterWindow
  end

  alias_method :original_pbShowMenu, :pbShowMenu
  def pbShowMenu
    original_pbShowMenu
    nuzlockeMode_toggleEncounterWindow(true)
  end

  alias_method :original_pbHideMenu, :pbHideMenu
  def pbHideMenu
    original_pbHideMenu
    nuzlockeMode_toggleEncounterWindow(false)
  end

  def nuzlockeMode_createEncounterWindow
    return if !NuzlockeMode.active?
    enc_types = $PokemonEncounters.nuzlockeMode_getEncounterTypes().map{|t| nuzlockeMode_generalize_enc_type(t)}.uniq
    if enc_types.length > 0
      @sprites["encwindow"] = EncounterWindow.new(enc_types, @viewport)
      pbBottomLeft(@sprites["encwindow"])
      @sprites["encwindow"].visible = true
    end
  end

  def nuzlockeMode_toggleEncounterWindow(value = nil)
    if @sprites["encwindow"]
      @sprites["encwindow"].visible = value || !@sprites["encwindow"].visible
    end
  end
end


# ----------------------------------------------------------------------------------------------------
# Utils
# ----------------------------------------------------------------------------------------------------

# Filters pkmn_list for not already encountered Pokémon
def nuzlockeMode_getEncounterablePokemon(pkmn_list)
  return pkmn_list if !NuzlockeMode.active?
  available_babies = $Trainer.nuzlockeMode_getAvailablePokemon().flat_map { |pkmn| nuzlockeMode_getBabySpecies(pkmn.species)}
  
  pkmn_list.select{ |pkmn| nuzlockeMode_getBabySpecies(pkmn.species).none? {|species| available_babies.include?(species)}}
end

# Returns a generalized encounter type
def nuzlockeMode_generalize_enc_type(enc_type)
  return "???" if enc_type == nil

  if enc_type.match(/^L/) # Land, LandDay, LandNight, LandMorning, LandAfternoon, LandEvening
    return "Land"
  elsif enc_type.match(/^C/) # Cave, CaveDay, CaveNight, CaveMorning, CaveAfternoon, CaveEvening
    return "Cave"
  elsif enc_type.match(/^Wa/) # Water, WaterDay, WaterNight, WaterMorning, WaterAfternoon, WaterEvening
    return "Water"
  elsif enc_type.match(/Rod$/) # OldRod, GoodRod, SuperRod
    return "Rod"
  elsif enc_type.match(/^H/) # HeadbuttLow, HeadbutHigh
    return "Headbutt"
  elsif enc_type.match(/^R/) # RockSmash
    return "RockSmash"
  elsif enc_type.match(/^B/) # BugContest
    return "BugContest"
  elsif enc_type.match(/^Web$/)
    return "Web"
  elsif enc_type.match(/^Shroom$/)
    return "Shroom"
  end

  return enc_type # encounters like voltorbs
end

# Returns a list of first stage species of the species
def nuzlockeMode_getBabySpecies(species)
  headId = getHeadID(species)
  bodyId = species_is_fusion(species) ? getBodyID(species) : nil
  head = headId ? GameData::Species.get(headId).get_baby_species : nil
  body = bodyId ? GameData::Species.get(bodyId).get_baby_species : nil
  return body ? [head, body] : [head]
end

class Player
  def nuzlockeMode_getAvailablePokemon()
    @party.select {|p| !p.fainted?} + $PokemonStorage.boxes.flat_map { |box| box.pokemon.select { |p| p != nil && !p.fainted?} }
  end

  def nuzlockeMode_getEncounterablePokemon(species_list)
    return species_list if !NuzlockeMode.active?
    species_babies = species_list.flat_map {|species| nuzlockeMode_getBabySpecies(species)}
    available_babies = nuzlockeMode_getAvailablePokemon().flat_map { |pkmn| nuzlockeMode_getBabySpecies(pkmn.species)}
    species_babies.select {|species| !available_babies.include?(species)} 
  end

  def nuzlockeMode_hasPokemon?(pkmn)
    nuzlockeMode_getEncounterablePokemon([pkmn]).length > 0
  end
end

class PokemonBag
  def nuzlockeMode_hasBalls?
    $BallTypes.any? { |(k, ball)| pbHasItem?(ball) }
  end
end

# Handle webs and shrooms in Viridian Forest
# TODO: handle other map specific encounters
alias :original_pbWildBattle :pbWildBattle
def pbWildBattle(species, level, outcomeVar=1, canRun=true, canLose=false)
  case $game_map.map_id
  when 491 # Viridian Forest
    if species == :SPINARAK # web
      NuzlockeMode.updateEncounterType(:Web)
    elsif species == :PARAS # shroom
      NuzlockeMode.updateEncounterType(:Shroom)
    end
  end
  return if NuzlockeMode.preventEncounter?
  original_pbWildBattle(species, level, outcomeVar, canRun, canLose)
end

# A lot of copy/paste because Pokémon generation and battle control is both in this function
# Handles encounter registration and denying already countered Pokémon
# Allows for shiny Pokémon to be encountered, if the encounter type is still available in that area
alias :original_pbWildBattleCore :pbWildBattleCore
def pbWildBattleCore(*args)
  return original_pbWildBattleCore(*args) if !NuzlockeMode.active?

  outcomeVar = $PokemonTemp.battleRules["outcomeVar"] || 1
  canLose    = $PokemonTemp.battleRules["canLose"] || false
  # Skip battle if the player has no able Pokémon, or if holding Ctrl in Debug mode
  if $Trainer.able_pokemon_count == 0 || ($DEBUG && Input.press?(Input::CTRL))
    pbMessage(_INTL("SKIPPING BATTLE...")) if $Trainer.pokemon_count > 0
    pbSet(outcomeVar,1)   # Treat it as a win
    $PokemonTemp.clearBattleRules
    $PokemonGlobal.nextBattleBGM       = nil
    $PokemonGlobal.nextBattleME        = nil
    $PokemonGlobal.nextBattleCaptureME = nil
    $PokemonGlobal.nextBattleBack      = nil
    $PokemonTemp.forced_alt_sprites=nil
    pbMEStop
    return 1   # Treat it as a win
  end
  # Record information about party Pokémon to be used at the end of battle (e.g.
  # comparing levels for an evolution check)
  Events.onStartBattle.trigger(nil)
  # Generate wild Pokémon based on the species and level
  foeParty = []
  sp = nil
  for arg in args
    if arg.is_a?(Pokemon)
      foeParty.push(arg)
    elsif arg.is_a?(Array)
      species = GameData::Species.get(arg[0]).id
      pkmn = pbGenerateWildPokemon(species,arg[1])
      foeParty.push(pkmn)
    elsif sp
      species = GameData::Species.get(sp).id
      pkmn = pbGenerateWildPokemon(species,arg)
      foeParty.push(pkmn)
      sp = nil
    else
      sp = arg
    end
  end
  
  encounterable = nuzlockeMode_getEncounterablePokemon(foeParty)
  shinyEncounter = foeParty.any? {|p| p.shiny?}
  #pbMessage(_INTL("Already caught: {1}", foeParty.map {|p| p.name})) if !encounterable
  return 1 if encounterable.empty? && !shinyEncounter
  raise _INTL("Expected a level after being given {1}, but one wasn't found.",sp) if sp
  # Calculate who the trainers and their party are
  playerTrainers    = [$Trainer]
  playerParty       = $Trainer.party
  playerPartyStarts = [0]
  room_for_partner = (foeParty.length > 1)
  if !room_for_partner && $PokemonTemp.battleRules["size"] &&
    !["single", "1v1", "1v2", "1v3"].include?($PokemonTemp.battleRules["size"])
    room_for_partner = true
  end
  if $PokemonGlobal.partner && !$PokemonTemp.battleRules["noPartner"] && room_for_partner
    ally = NPCTrainer.new($PokemonGlobal.partner[1],$PokemonGlobal.partner[0])
    ally.id    = $PokemonGlobal.partner[2]
    ally.party = $PokemonGlobal.partner[3]
    playerTrainers.push(ally)
    playerParty = []
    $Trainer.party.each { |pkmn| playerParty.push(pkmn) }
    playerPartyStarts.push(playerParty.length)
    ally.party.each { |pkmn| playerParty.push(pkmn) }
    setBattleRule("double") if !$PokemonTemp.battleRules["size"]
  end
  # Create the battle scene (the visual side of it)
  scene = pbNewBattleScene
  # Create the battle class (the mechanics side of it)
  battle = PokeBattle_Battle.new(scene,playerParty,foeParty,playerTrainers,nil)
  battle.party1starts = playerPartyStarts
  # Set various other properties in the battle class
  pbPrepareBattle(battle)
  $PokemonTemp.clearBattleRules
  # Perform the battle itself
  decision = 0
  pbBattleAnimation(pbGetWildBattleBGM(foeParty),(foeParty.length==1) ? 0 : 2,foeParty) {
    pbSceneStandby {
      decision = battle.pbStartBattle
    }
    pbAfterBattle(decision,canLose)
  }
  Input.update
  # Save the result of the battle in a Game Variable (1 by default)
  #    0 - Undecided or aborted
  #    1 - Player won
  #    2 - Player lost
  #    3 - Player or wild Pokémon ran from battle, or player forfeited the match
  #    4 - Wild Pokémon was caught
  #    5 - Draw
  pbSet(outcomeVar,decision)

  if !shinyEncounter
    NuzlockeMode.registerEncounter if !shinyEncounter # 
    $PokemonEncounters.nuzlockeMode_updateEncounterTables
  end
  
  NuzlockeMode.resetEncounterType # could be one method
  return decision
end