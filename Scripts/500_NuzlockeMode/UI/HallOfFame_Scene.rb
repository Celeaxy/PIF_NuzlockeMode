$nuzlockeModeOldHallOfFameGameMode = HallOfFame_Scene.public_instance_method(:writeGameMode)
class HallOfFame_Scene
  def writeGameMode(overlay, x, y)
    return $nuzlockeModeOldHallOfFameGameMode.bind(self).call(overlay, x, y) if !NuzlockeMode.active?

    gameMode = "Classic"
    if $game_switches[SWITCH_MODERN_MODE]
      gameMode = "Remix"
    end
    if $game_switches[SWITCH_EXPERT_MODE]
      gameMode = "Expert"
    end
    if $game_switches[SWITCH_SINGLE_POKEMON_MODE]
      pokemon_number = pbGet(VAR_SINGLE_POKEMON_MODE)
      if pokemon_number.is_a?(Integer) && pokemon_number > 0
        pokemon = GameData::Species.get(pokemon_number)
        gameMode = pokemon.real_name + " mode"
      else
        gameMode = "Debug"
      end
    end
    if $game_switches[SWITCH_RANDOMIZED_AT_LEAST_ONCE]
      gameMode = "Randomized"
    end
    if $game_switches[ENABLED_DEBUG_MODE_AT_LEAST_ONCE] || $DEBUG
      gameMode = "Debug"
    end

    pbDrawTextPositions(overlay, [[_INTL("{1} {2} ({3})", gameMode, 'Nuzlocke', getDifficulty), x, y, 2, BASECOLOR, SHADOWCOLOR]])
  end
end