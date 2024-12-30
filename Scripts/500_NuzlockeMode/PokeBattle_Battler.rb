class PokeBattle_Battler
  def pbFaint(showMessage=true)
    if !fainted?
      PBDebug.log("!!!***Can't faint with HP greater than 0")
      return
    end
    # DIE
    return if @fainted   # Has already fainted properly
    @battle.pbDisplayBrief(_INTL("{1} died!",pbThis)) if showMessage
    updateSpirits()
    PBDebug.log("[Pokémon died] #{pbThis} (#{@index})") if !showMessage
    @battle.scene.pbFaintBattler(self)
    pbInitEffects(false)
    # Reset status
    self.status      = :DEAD
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