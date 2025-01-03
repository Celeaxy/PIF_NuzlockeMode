# ----------------------------------------------------------------------------------------------------
# TODO:
#   - Prohibit taking dead pokemon into party
# ----------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------
# NuzlockeMode status module
# ----------------------------------------------------------------------------------------------------

GameData::Status.register({
  :id        => :POKERUS,
  :id_number => 6,
  :name      => _INTL("Pokerus"),
})

GameData::Status.register({
  :id        => :DEAD,
  :id_number => 7,
  :name      => _INTL("Dead"),
})

class Pokemon
  alias_method :original_heal_HP, :heal_HP
  def heal_HP
    return if NuzlockeMode.active? && fainted?
    original_heal_HP
  end
end

# ----------------------------------------------------------------------------------------------------
# Prevent fusing, unfusing or reversing a dead Pokémon
# ---------------------------------------------------------------------------------------------------- 
class PokemonStorageScreen
  alias_method :original_pbUnfuseFromPC, :pbUnfuseFromPC
  def pbUnfuseFromPC(selected)
    pokemon = @storage[selected[0], selected[1]]
    if NuzlockeMode.active? && pokemon.fainted?
      pbMessage("You can't unfuse a dead Pokémon!")
      return
    end
    original_pbUnfuseFromPC(selected)
  end

  alias_method :original_pbFuseFromPC, :pbFuseFromPC
  def pbFuseFromPC(selected, heldpoke)
    if NuzlockeMode.active?
      pokemon = @storage[selected[0], selected[1]]
      if heldpoke && heldpoke.fainted? || pokemon.fainted?
        pbMessage("You can't fuse a dead Pokémon!")
        return
      end
    end
    original_pbFuseFromPC(selected, heldpoke)
  end

  alias_method :original_pbFusionCommands, :pbFusionCommands
  def pbFusionCommands(selected)
    if NuzlockeMode.active?
      heldpoke = pbHeldPokemon
      pokemon = @storage[selected[0], selected[1]]
      if heldpoke.fainted? || pokemon && pokemon.fainted?
        pbMessage("You can't fuse a dead Pokémon!")
        return
      end
    end
    original_pbFusionCommands(selected)
  end

  alias_method :original_reverseFromPC, :reverseFromPC
  def reverseFromPC(selected)
    if NuzlockeMode.active?
      box = selected[0]
      index = selected[1]
      pokemon = @storage[box, index]
      if pokemon.fainted?
        pbMessage("You can't reverse a dead Pokémon!")
        return
      end
    end
    original_reverseFromPC(selected)
  end
end

alias :original_pbDNASplicing :pbDNASplicing
def pbDNASplicing(pokemon, scene, item = :DNASPLICERS)
  if NuzlockeMode.active? && pokemon.fainted?
    if pokemon.fused
      pbMessage("You can't unfuse a dead Pokémon!")
    else
      pbMessage("You can't fuse a dead Pokémon!")
    end
    return false
  end
  original_pbDNASplicing(pokemon, scene, item)
end

alias :original_pbUnfuse :pbUnfuse
def pbUnfuse(pokemon, scene, supersplicers, pcPosition = nil)
  if NuzlockeMode.active? && pokemon.fainted?
    pbMessage("You can't unfuse a dead Pokémon!")
    return false
  end
  original_pbUnfuse(pokemon, scene, supersplicers, pcPosition)
end

alias :original_pbFuse :pbFuse
def pbFuse(pokemon_body, pokemon_head, splicer_item)
  if NuzlockeMode.active?
    return false if pokemon_body.fainted? || pokemon_head.fainted?        
  end
  original_pbFuse(pokemon_body, pokemon_head, splicer_item)
end

alias :original_reverseFusion :reverseFusion
def reverseFusion(pokemon)
  if NuzlockeMode.active? && pokemon.fainted?
    pbMessage("You can't reverse a dead Pokémon!")
    return false 
  end
  original_reverseFusion(pokemon)
end

# Much copy/paste since no dedicated functions to hook into
ItemHandlers::UseOnPokemon.add(:DNAREVERSER, proc { |item, pokemon, scene|
  if !pokemon.isFusion?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end

  if NuzlockeMode.active? && pokemon.fainted?
    pbMessage("You can't reverse a dead Pokémon!")
    next false
  end
  
  if Kernel.pbConfirmMessageSerious(_INTL("Should {1} be reversed?", pokemon.name))
    reverseFusion(pokemon)
    scene.pbRefreshAnnotations(proc { |p| pbCheckEvolution(p, item) > 0 })
    scene.pbRefresh
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:INFINITEREVERSERS, proc { |item, pokemon, scene|
  if !pokemon.isFusion?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end  

  if NuzlockeMode.active? && pokemon.fainted?
    pbMessage("You can't reverse a dead Pokémon!")
    next false
  end
  
  if Kernel.pbConfirmMessageSerious(_INTL("Should {1} be reversed?", pokemon.name))
    body = getBasePokemonID(pokemon.species, true)
    head = getBasePokemonID(pokemon.species, false)
    newspecies = (head) * Settings::NB_POKEMON + body

    body_exp = pokemon.exp_when_fused_body
    head_exp = pokemon.exp_when_fused_head

    pokemon.exp_when_fused_body = head_exp
    pokemon.exp_when_fused_head = body_exp

    #play animation
    pbFadeOutInWithMusic(99999) {
      fus = PokemonEvolutionScene.new
      fus.pbStartScreen(pokemon, newspecies, true)
      fus.pbEvolution(false, true)
      fus.pbEndScreen
      scene.pbRefreshAnnotations(proc { |p| pbCheckEvolution(p, item) > 0 })
      scene.pbRefresh
    }
    next true
  end
  next false
})

# Hijack to reduce loading time, since loading twice takes too long and causes flickering
class AnimatedBitmap
  alias_method :original_initialize, :initialize
  def initialize(file, hue = 0)
    if file == _INTL("Graphics/Pictures/statuses")
      file = _INTL("Data/NuzlockeMode_Data/statuses")
    end
    original_initialize(file, hue)
  end
end

#Display dead status on party panel
class PokemonPartyPanel
  alias_method :original_initialize, :initialize
  def initialize(pokemon, index, viewport = nil)
    original_initialize(pokemon, index, viewport)
    if pokemon.fainted?
      status = GameData::Status.get(:DEAD).id_number
      statusrect = Rect.new(0, 16 * status, 44, 16)
      @overlaysprite.bitmap.blt(78, 68, @statuses.bitmap, statusrect)
    end
  end
end


# ----------------------------------------------------------------------------------------------------
# Pokémon storage
# ----------------------------------------------------------------------------------------------------

class SpriteWrapper
    # needed to access the dimensions of the scaled pokemon sprite
    def sprite
      @sprite 
    end
end


class PokemonStorageScene
  alias_method :original_pbUpdateOverlay, :pbUpdateOverlay
  def pbUpdateOverlay(selection, party = nil)
    original_pbUpdateOverlay(selection, party)
    return if !NuzlockeMode.active?
    pokemon = nil
    if @screen.pbHeldPokemon && !@screen.fusionMode
      pokemon = @screen.pbHeldPokemon
    elsif selection >= 0
      pokemon = (party) ? party[selection] : @storage[@storage.currentBox, selection]
    end
    
    if !@sprites["dead_status"] # create only once
      return if !pokemon
      status = GameData::Status.get(:DEAD).id_number
      x = 90 - 22
      y = 134 + @sprites["pokemon"].sprite.fullheight / 2 - 30
      @sprites["dead_status"] = IconSprite.new(x, y, @boxsidesviewport)
      @sprites["dead_status"].setBitmap("Data/NuzlockeMode_Data/statuses")
      @sprites["dead_status"].src_rect = Rect.new(0, 16 * status, 44, 16)
    end
      
    @sprites["dead_status"].visible = pokemon && pokemon.fainted?
  end
end

# ----------------------------------------------------------------------------------------------------
# Battle
# ----------------------------------------------------------------------------------------------------

# Pretty intrusive to change only a message, but w/e
# 
class PokeBattle_Battler
  def pbFaint(showMessage=true)
    if !fainted?
      PBDebug.log("!!!***Can't faint with HP greater than 0")
      return
    end
    # DIE
    return if @fainted   # Has already fainted properly
    msg = NuzlockeMode.active? && pbOwnedByPlayer? ? "died" : "fainted" 
    @battle.pbDisplayBrief(_INTL("{1} {2}!",pbThis, msg)) if showMessage
    updateSpirits()
    PBDebug.log(_INTL("[Pokémon {1}] #{pbThis} (#{@index})", msg)) if !showMessage
    @battle.scene.pbFaintBattler(self)
    pbInitEffects(false)
    # Reset status
    self.status      = NuzlockeMode.active? ? :DEAD : :NONE
    self.statusCount = 0
    # Reset form
    @battle.peer.pbOnLeavingBattle(@battle,@pokemon,@battle.usedInBattle[idxOwnSide][@index/2])
    @pokemon.makeUnmega if mega?
    @pokemon.makeUnprimal if primal?
    # Do other things
    @battle.pbClearChoice(@index)   # Reset choice
    pbOwnSide.effects[PBEffects::LastRoundFainted] = @battle.turnCount
    # Check other battlers' abilities that trigger upon a battler fainting
    pbAbilitiesOnFainting
    # Check for end of primordial weather
    @battle.pbEndPrimordialWeather
  end
end