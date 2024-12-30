class PokemonPartyScreen
  def pbLevelUp(pkmn)
    loop do
      commands = [_INTL("Once"), _INTL("Fully"), _INTL("Cancel")]
      command = @scene.pbShowCommands(_INTL("How often to level?"), commands)
      case command
      when 0 #Once
        if can_use_rare_candy(pkmn)
          ItemHandlers.triggerUseOnPokemon(:RARECANDY, pkmn, self)
        end
      when 1 #Fully
        while can_use_rare_candy(pkmn)
          ItemHandlers.triggerUseOnPokemon(:RARECANDY, pkmn, self)
        end
        break
      else
        break
      end
      if !can_use_rare_candy(pkmn)
        break
      end
    end
  end

  def pbPokemonScreen
    @scene.pbStartScene(@party,
                        (@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."), nil)
    loop do
      @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
      pkmnid = @scene.pbChoosePokemon(false, -1, 1)
      break if (pkmnid.is_a?(Numeric) && pkmnid < 0) || (pkmnid.is_a?(Array) && pkmnid[1] < 0)
      if pkmnid.is_a?(Array) && pkmnid[0] == 1 # Switch
        @scene.pbSetHelpText(_INTL("Move to where?"))
        oldpkmnid = pkmnid[1]
        pkmnid = @scene.pbChoosePokemon(true, -1, 2)
        if pkmnid >= 0 && pkmnid != oldpkmnid
          pbSwitch(oldpkmnid, pkmnid)
        end
        next
      end
      pkmn = @party[pkmnid]
      commands = []
      cmdSummary = -1
      cmdLevelUp = -1
      cmdNickname = -1
      cmdDebug = -1
      cmdMoves = [-1] * pkmn.numMoves
      cmdSwitch = -1
      cmdMail = -1
      cmdItem = -1
      cmdHat = -1

      # Build the commands
      commands[cmdSummary = commands.length] = _INTL("Summary")
      commands[cmdLevelUp = commands.length] = _INTL("Level up") if NuzlockeMode.active? && can_use_rare_candy(pkmn)
      commands[cmdDebug = commands.length] = _INTL("Debug") if $DEBUG
      if !pkmn.egg?
        # Check for hidden moves and add any that were found
        pkmn.moves.each_with_index do |m, i|
          if [:MILKDRINK, :SOFTBOILED].include?(m.id) ||
            HiddenMoveHandlers.hasHandler(m.id)
            commands[cmdMoves[i] = commands.length] = [m.name, 1]
          end
        end
      end
      commands[cmdSwitch = commands.length] = _INTL("Switch") if @party.length > 1
      commands[cmdHat = commands.length] = _INTL("Hat") if !pkmn.egg? && $game_switches[SWITCH_UNLOCKED_POKEMON_HATS]
      if !pkmn.egg?
        if pkmn.mail
          commands[cmdMail = commands.length] = _INTL("Mail")
        else
          commands[cmdItem = commands.length] = _INTL("Item")
        end
      end
      commands[cmdNickname = commands.length] = _INTL("Nickname") if !pkmn.egg?
      commands[commands.length] = _INTL("Cancel")
      command = @scene.pbShowCommands(_INTL("Do what with {1}?", pkmn.name), commands)
      havecommand = false
      cmdMoves.each_with_index do |cmd, i|
        next if cmd < 0 || cmd != command
        havecommand = true
        if [:MILKDRINK, :SOFTBOILED].include?(pkmn.moves[i].id)
          amt = [(pkmn.totalhp / 5).floor, 1].max
          if pkmn.hp <= amt
            pbDisplay(_INTL("Not enough HP..."))
            break
          end
          @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
          oldpkmnid = pkmnid
          loop do
            @scene.pbPreSelect(oldpkmnid)
            pkmnid = @scene.pbChoosePokemon(true, pkmnid)
            break if pkmnid < 0
            newpkmn = @party[pkmnid]
            movename = pkmn.moves[i].name
            if pkmnid == oldpkmnid
              pbDisplay(_INTL("{1} can't use {2} on itself!", pkmn.name, movename))
            elsif newpkmn.egg?
              pbDisplay(_INTL("{1} can't be used on an Egg!", movename))
            elsif newpkmn.hp == 0 || newpkmn.hp == newpkmn.totalhp
              pbDisplay(_INTL("{1} can't be used on that Pokémon.", movename))
            else
              pkmn.hp -= amt
              hpgain = pbItemRestoreHP(newpkmn, amt)
              @scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.", newpkmn.name, hpgain))
              pbRefresh
            end
            break if pkmn.hp <= amt
          end
          @scene.pbSelect(oldpkmnid)
          pbRefresh
          break
        elsif pbCanUseHiddenMove?(pkmn, pkmn.moves[i].id)
          if pbConfirmUseHiddenMove(pkmn, pkmn.moves[i].id)
            @scene.pbEndScene
            if pkmn.moves[i].id == :FLY || pkmn.moves[i].id == :TELEPORT
              ret = pbBetterRegionMap(-1, true, true)
              if ret
                $PokemonTemp.flydata = ret
                return [pkmn, pkmn.moves[i].id]
              end
              @scene.pbStartScene(@party,
                                  (@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
              break
            end
            return [pkmn, pkmn.moves[i].id]
          end
        end
      end
      next if havecommand
      if cmdSummary >= 0 && command == cmdSummary
        @scene.pbSummary(pkmnid) {
          @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
        }
      elsif cmdLevelUp >= 0 && command == cmdLevelUp
        pbLevelUp(pkmn)
      elsif cmdHat >= 0 && command == cmdHat
        pbPokemonHat(pkmn)
      elsif cmdNickname >= 0 && command == cmdNickname
        pbPokemonRename(pkmn, pkmnid)
      elsif cmdDebug >= 0 && command == cmdDebug
        pbPokemonDebug(pkmn, pkmnid)
      elsif cmdSwitch >= 0 && command == cmdSwitch
        @scene.pbSetHelpText(_INTL("Move to where?"))
        oldpkmnid = pkmnid
        pkmnid = @scene.pbChoosePokemon(true)
        if pkmnid >= 0 && pkmnid != oldpkmnid
          pbSwitch(oldpkmnid, pkmnid)
        end
      elsif cmdMail >= 0 && command == cmdMail
        command = @scene.pbShowCommands(_INTL("Do what with the mail?"),
                                        [_INTL("Read"), _INTL("Take"), _INTL("Cancel")])
        case command
        when 0 # Read
          pbFadeOutIn {
            pbDisplayMail(pkmn.mail, pkmn)
            @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
          }
        when 1 # Take
          if pbTakeItemFromPokemon(pkmn, self)
            pbRefreshSingle(pkmnid)
          end
        end
      elsif cmdItem >= 0 && command == cmdItem
        itemcommands = []
        cmdUseItem = -1
        cmdGiveItem = -1
        cmdTakeItem = -1
        cmdMoveItem = -1
        # Build the commands
        itemcommands[cmdUseItem = itemcommands.length] = _INTL("Use")
        itemcommands[cmdGiveItem = itemcommands.length] = _INTL("Give")
        itemcommands[cmdTakeItem = itemcommands.length] = _INTL("Take") if pkmn.hasItem?
        itemcommands[cmdMoveItem = itemcommands.length] = _INTL("Move") if pkmn.hasItem? &&
          !GameData::Item.get(pkmn.item).is_mail?
        itemcommands[itemcommands.length] = _INTL("Cancel")
        command = @scene.pbShowCommands(_INTL("Do what with an item?"), itemcommands)
        if cmdUseItem >= 0 && command == cmdUseItem # Use
          item = @scene.pbUseItem($PokemonBag, pkmn) {
            @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
          }
          if item
            pbUseItemOnPokemon(item, pkmn, self)
            pbRefreshSingle(pkmnid)
          end
        elsif cmdGiveItem >= 0 && command == cmdGiveItem # Give
          item = @scene.pbChooseItem($PokemonBag) {
            @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
          }
          if item
            if pbGiveItemToPokemon(item, pkmn, self, pkmnid)
              pbRefreshSingle(pkmnid)
            end
          end
        elsif cmdTakeItem >= 0 && command == cmdTakeItem # Take
          if pbTakeItemFromPokemon(pkmn, self)
            pbRefreshSingle(pkmnid)
          end
        elsif cmdMoveItem >= 0 && command == cmdMoveItem # Move
          item = pkmn.item
          itemname = item.name
          @scene.pbSetHelpText(_INTL("Move {1} to where?", itemname))
          oldpkmnid = pkmnid
          loop do
            @scene.pbPreSelect(oldpkmnid)
            pkmnid = @scene.pbChoosePokemon(true, pkmnid)
            break if pkmnid < 0
            newpkmn = @party[pkmnid]
            break if pkmnid == oldpkmnid
            if newpkmn.egg?
              pbDisplay(_INTL("Eggs can't hold items."))
            elsif !newpkmn.hasItem?
              newpkmn.item = item
              pkmn.item = nil
              @scene.pbClearSwitching
              pbRefresh
              pbDisplay(_INTL("{1} was given the {2} to hold.", newpkmn.name, itemname))
              break
            elsif GameData::Item.get(newpkmn.item).is_mail?
              pbDisplay(_INTL("{1}'s mail must be removed before giving it an item.", newpkmn.name))
            else
              newitem = newpkmn.item
              newitemname = newitem.name
              if newitem == :LEFTOVERS
                pbDisplay(_INTL("{1} is already holding some {2}.\1", newpkmn.name, newitemname))
              elsif newitemname.starts_with_vowel?
                pbDisplay(_INTL("{1} is already holding an {2}.\1", newpkmn.name, newitemname))
              else
                pbDisplay(_INTL("{1} is already holding a {2}.\1", newpkmn.name, newitemname))
              end
              if pbConfirm(_INTL("Would you like to switch the two items?"))
                newpkmn.item = item
                pkmn.item = newitem
                @scene.pbClearSwitching
                pbRefresh
                pbDisplay(_INTL("{1} was given the {2} to hold.", newpkmn.name, itemname))
                pbDisplay(_INTL("{1} was given the {2} to hold.", pkmn.name, newitemname))
                break
              end
            end
          end
        end
      end
    end
    @scene.pbEndScene
    return nil
  end
end