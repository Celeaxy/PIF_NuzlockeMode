# ----------------------------------------------------------------------------------------------------
# TODO:
#   - Static encounters like Voltorbs etc.
#   - Restrict leaving arena after entering
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

  def self.preventEncounter?(enc_type = nil)
    return false if !NuzlockeMode.active?
    self.hadEncounter?(enc_type)
  end

  def self.hadEncounter?(enc_type = nil)
    encounter_type = enc_type || $PokemonEncounters.encounter_type
    self.encounters.include?([$game_map.map_id, nuzlockeMode_generalize_enc_type(encounter_type)])
  end

  def self.registerEncounter(enc_type = nil)
    return if !NuzlockeMode.active?
    encounter_type = enc_type || $PokemonEncounters.encounter_type
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

    if NuzlockeMode.active?
      @map_ID = map_ID
      nuzlockeMode_updateEncounterTables
    end
  end

  def nuzlockeMode_getAvailableEncounters
    return @encounter_tables if !NuzlockeMode.active?

    available_babies = $Trainer.nuzlockeMode_getAvailablePokemon().flat_map { |pkmn| nuzlockeMode_getBabySpecies(pkmn.species)}
    filtered_tables_by_type = @encounter_tables.select{ |enc_type, enc_list| !NuzlockeMode.preventEncounter?(enc_type)}
    
    Hash[filtered_tables_by_type.map { |enc_type, enc_list| [enc_type, enc_list.select { |enc| !nuzlockeMode_getBabySpecies(enc[1]).any? { |p| available_babies.include?(p)}}]}]
  end

  def nuzlockeMode_getEncounterTypes
    @encounter_tables.map {|k,v| k}
  end

  def nuzlockeMode_updateEncounterTables
    @encounter_tables = nuzlockeMode_getAvailableEncounters
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
    return false if !original_allow_encounter?(enc_data, repel_active) || NuzlockeMode.preventEncounter?
    NuzlockeMode.registerEncounter
    nuzlockeMode_updateEncounterTables
    return true
  end
end


# ----------------------------------------------------------------------------------------------------
# Hooks to register and prevent encounters
# ----------------------------------------------------------------------------------------------------

alias :original_pbDefaultRockSmashEncounter :pbDefaultRockSmashEncounter
def pbDefaultRockSmashEncounter(minLevel,maxLevel)
  return false if NuzlockeMode.preventEncounter?(:RockSmash)
  pkmn = getRandomizedTo(:GEODUDE)
  return false if NuzlockeMode.active? && $Trainer.nuzlockeMode_hasPokemon?(pkmn)

  ret = original_pbDefaultRockSmashEncounter(minLevel, maxLevel)
  if ret
    NuzlockeMode.registerEncounter(:RockSmash)
    nuzlockeMode_updateEncounterTables
  end
  ret
end

alias :original_pbEncounter :pbEncounter
def pbEncounter(enc_type)
  return false if NuzlockeMode.preventEncounter?(enc_type)

  ret = original_pbEncounter(enc_type)
  if ret
    NuzlockeMode.registerEncounter(enc_type)
    nuzlockeMode_updateEncounterTables
  end
  ret
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
    available_babies = nuzlockeMode_availablePokemon().flat_map { |pkmn| nuzlockeMode_getBabySpecies(pkmn.species)}
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
