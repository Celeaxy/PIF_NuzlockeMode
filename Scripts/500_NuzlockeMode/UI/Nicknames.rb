class PokemonEntryScene
  attr_reader :sprites # make sprites accessible to change text of helpwindow
end

class PokemonEntry
  def pbStartScreen(helptext,minlength,maxlength,initialText,mode=-1,pokemon=nil)
    @scene.pbStartScene(helptext,minlength,maxlength,initialText,mode,pokemon)
    ret=@scene.pbEntry
    if pokemon.respond_to?(:speciesName) && NuzlockeMode.active?
      while ["", pokemon.speciesName].include?(ret)
        @scene.sprites["helpwindow"].text = "In a nuzlocke a pokemon must be nicknamed!"
        ret=@scene.pbEntry
      end
    end
    @scene.pbEndScene
    return ret
  end
end

def pbNickname(pkmn)
  species_name = pkmn.speciesName
  if NuzlockeMode.active? || pbConfirmMessage(_INTL("Would you like to give a nickname to {1}?", species_name))
    pkmn.name = pbEnterPokemonName(_INTL("{1}'s nickname?", species_name),
                                   0, Pokemon::MAX_NAME_SIZE, "", pkmn)
  end
end

module PokeBattle_BattleCommon
  #=============================================================================
  # Store caught Pokémon
  #=============================================================================
  def pbStorePokemon(pkmn)
    # Nickname the Pokémon (unless it's a Shadow Pokémon)
    if !pkmn.shadowPokemon?
      if NuzlockeMode.active? || pbDisplayConfirm(_INTL("Would you like to give a nickname to {1}?", pkmn.name))
        nickname = @scene.pbNameEntry(_INTL("{1}'s nickname?", pkmn.speciesName), pkmn)
        pkmn.name = nickname
      end
    end
    # Store the Pokémon
    currentBox = @peer.pbCurrentBox
    storedBox = @peer.pbStorePokemon(pbPlayer, pkmn)
    if storedBox < 0
      pbDisplayPaused(_INTL("{1} has been added to your party.", pkmn.name))
      @initialItems[0][pbPlayer.party.length - 1] = pkmn.item_id if @initialItems
      return
    end
    # Messages saying the Pokémon was stored in a PC box
    creator = @peer.pbGetStorageCreatorName
    curBoxName = @peer.pbBoxName(currentBox)
    boxName = @peer.pbBoxName(storedBox)
    if storedBox != currentBox
      if creator
        pbDisplayPaused(_INTL("Box \"{1}\" on {2}'s PC was full.", curBoxName, creator))
      else
        pbDisplayPaused(_INTL("Box \"{1}\" on someone's PC was full.", curBoxName))
      end
      pbDisplayPaused(_INTL("{1} was transferred to box \"{2}\".", pkmn.name, boxName))
    else
      if creator
        pbDisplayPaused(_INTL("{1} was transferred to {2}'s PC.", pkmn.name, creator))
      else
        pbDisplayPaused(_INTL("{1} was transferred to someone's PC.", pkmn.name))
      end
      pbDisplayPaused(_INTL("It was stored in box \"{1}\".", boxName))
    end
  end
end