GameData::Status.register({
  :id        => :POKERUS,
  :id_number => 7,
  :name      => _INTL("Pokerus"),
})

GameData::Status.register({
  :id        => :DEAD,
  :id_number => 8,
  :name      => _INTL("Dead"),
})

class Pokemon
  alias_method :original_heal_HP, :heal_HP
  def heal_HP
    return if fainted? && NuzlockeMode.active?
    original_heal_HP
  end
end

def pbUnfuse(pokemon, scene, supersplicers, pcPosition = nil)
  fainted = pokemon.fainted?
  if pokemon.species_data.id_number > (NB_POKEMON * NB_POKEMON) + NB_POKEMON #triple fusion
    scene.pbDisplay(_INTL("{1} cannot be unfused.", pokemon.name))
    return false
  end

  pokemon.spriteform_body=nil
  pokemon.spriteform_head=nil

  bodyPoke = getBasePokemonID(pokemon.species_data.id_number, true)
  headPoke = getBasePokemonID(pokemon.species_data.id_number, false)

  if (pokemon.obtain_method == 2 || pokemon.ot != $Trainer.name) # && !canunfuse
    scene.pbDisplay(_INTL("You can't unfuse a Pokémon obtained in a trade!"))
    return false
  else
    if Kernel.pbConfirmMessageSerious(_INTL("Should {1} be unfused?", pokemon.name))
      keepInParty = 0
      if $Trainer.party.length >= 6 && !pcPosition
        scene.pbDisplay(_INTL("Your party is full! Keep which Pokémon in party?"))
        choice = Kernel.pbMessage("Select a Pokémon to keep in your party.", [_INTL("{1}", PBSpecies.getName(bodyPoke)), _INTL("{1}", PBSpecies.getName(headPoke)), "Cancel"], 2)
        if choice == 2
          return false
        else
          keepInParty = choice
        end
      end

      scene.pbDisplay(_INTL("Unfusing ... "))
      scene.pbDisplay(_INTL(" ... "))
      scene.pbDisplay(_INTL(" ... "))

      if pokemon.exp_when_fused_head == nil || pokemon.exp_when_fused_body == nil
        new_level = calculateUnfuseLevelOldMethod(pokemon, supersplicers)
        body_level = new_level
        head_level = new_level
        poke1 = Pokemon.new(bodyPoke, body_level)
        poke2 = Pokemon.new(headPoke, head_level)
      else
        exp_body = pokemon.exp_when_fused_body + pokemon.exp_gained_since_fused
        exp_head = pokemon.exp_when_fused_head + pokemon.exp_gained_since_fused

        poke1 = Pokemon.new(bodyPoke, pokemon.level)
        poke2 = Pokemon.new(headPoke, pokemon.level)
        poke1.exp = exp_body
        poke2.exp = exp_head
      end
      body_level = poke1.level
      head_level = poke2.level

      pokemon.exp_gained_since_fused = 0
      pokemon.exp_when_fused_head = nil
      pokemon.exp_when_fused_body = nil

      if pokemon.shiny?
        pokemon.shiny = false
        if pokemon.bodyShiny? && pokemon.headShiny?
          pokemon.shiny = true
          poke2.shiny = true
          pokemon.natural_shiny = true if pokemon.natural_shiny && !pokemon.debug_shiny
          poke2.natural_shiny = true if pokemon.natural_shiny && !pokemon.debug_shiny
        elsif pokemon.bodyShiny?
          pokemon.shiny = true
          poke2.shiny = false
          pokemon.natural_shiny = true if pokemon.natural_shiny && !pokemon.debug_shiny
        elsif pokemon.headShiny?
          poke2.shiny = true
          pokemon.shiny = false
          poke2.natural_shiny = true if pokemon.natural_shiny && !pokemon.debug_shiny
        else
          #shiny was obtained already fused
          if rand(2) == 0
            pokemon.shiny = true
          else
            poke2.shiny = true
          end
        end
      end

      pokemon.ability_index = pokemon.body_original_ability_index if pokemon.body_original_ability_index
      poke2.ability_index = pokemon.head_original_ability_index if pokemon.head_original_ability_index

      pokemon.ability2_index=nil
      pokemon.ability2=nil
      poke2.ability2_index=nil
      poke2.ability2=nil

      pokemon.debug_shiny = true if pokemon.debug_shiny && pokemon.body_shiny
      poke2.debug_shiny = true if pokemon.debug_shiny && poke2.head_shiny

      pokemon.body_shiny = false
      pokemon.head_shiny = false

      if !pokemon.shiny?
        pokemon.debug_shiny = false
      end
      if !poke2.shiny?
        poke2.debug_shiny = false
      end

      if $Trainer.party.length >= 6
        if (keepInParty == 0)
          $PokemonStorage.pbStoreCaught(poke2)
          scene.pbDisplay(_INTL("{1} was sent to the PC.", poke2.name))
        else
          poke2 = Pokemon.new(bodyPoke, body_level)
          poke1 = Pokemon.new(headPoke, head_level)

          if pcPosition != nil
            box = pcPosition[0]
            index = pcPosition[1]
            #todo: store at next available position from current position
            $PokemonStorage.pbStoreCaught(poke2)
          else
            $PokemonStorage.pbStoreCaught(poke2)
            scene.pbDisplay(_INTL("{1} was sent to the PC.", poke2.name))
          end

        end
      else
        if pcPosition != nil
          box = pcPosition[0]
          index = pcPosition[1]

          #todo: store at next available position from current position
          $PokemonStorage.pbStoreCaught(poke2)
        else
          Kernel.pbAddPokemonSilent(poke2, poke2.level)
        end
      end

      #On ajoute les poke au pokedex
      $Trainer.pokedex.set_seen(poke1.species)
      $Trainer.pokedex.set_owned(poke1.species)
      $Trainer.pokedex.set_seen(poke2.species)
      $Trainer.pokedex.set_owned(poke2.species)

      pokemon.species = poke1.species
      pokemon.level = poke1.level
      pokemon.name = poke1.name
      pokemon.moves = poke1.moves
      pokemon.obtain_method = 0
      poke1.obtain_method = 0

      if NuzlockeMode.active? && fainted
        pokemon.hp = 0
        poke1.hp = 0
        poke2.hp = 0
      end
      #scene.pbDisplay(_INTL(p1.to_s + " " + p2.to_s))
      scene.pbHardRefresh
      scene.pbDisplay(_INTL("Your Pokémon were successfully unfused! "))
      return true
    end
  end
end

# class PokemonSummary_Scene
#   def drawPage(page)
#     if @pokemon.egg?
#       drawPageOneEgg
#       return
#     end
#     @sprites["itemicon"].item = @pokemon.item_id
#     overlay = @sprites["overlay"].bitmap
#     overlay.clear
#     base = Color.new(248, 248, 248)
#     shadow = Color.new(104, 104, 104)
#     # Set background image
#     @sprites["background"].setBitmap("Graphics/Pictures/Summary/bg_#{page}") if page < NB_PAGES
#     imagepos = []
#     # Show the Poké Ball containing the Pokémon
#     ballimage = sprintf("Graphics/Pictures/Summary/icon_ball_%s", @pokemon.poke_ball)
#     if !pbResolveBitmap(ballimage)
#       ballimage = sprintf("Graphics/Pictures/Summary/icon_ball_%02d", pbGetBallType(@pokemon.poke_ball))
#     end
#     imagepos.push([ballimage, 14, 60])
#     # Show status/fainted/Pokérus infected icon
#     status = 0
#     if @pokemon.fainted?
#       status = GameData::Status.get(:BURN).id_number
#     elsif @pokemon.status != :NONE
#       status = GameData::Status.get(@pokemon.status).id_number
#     elsif @pokemon.pokerusStage == 1
#       status = GameData::Status::DATA.keys.length / 2 + 1
#     end
#     status -= 1
#     if status >= 0
#       imagepos.push(["Data/Scripts/NuzlockeMod/statuses", 124, 100, 0, 16 * status, 44, 16])
#     end
#     # Show Pokérus cured icon
#     if @pokemon.pokerusStage == 2
#       imagepos.push([sprintf("Graphics/Pictures/Summary/icon_pokerus"), 176, 100])
#     end
#     # Show shininess star
#     if @pokemon.shiny?
#       addShinyStarsToGraphicsArray(imagepos, 2, 134, @pokemon.bodyShiny?, @pokemon.headShiny?, @pokemon.debugShiny?, nil, nil, nil, nil, true)
#       #imagepos.push([sprintf("Graphics/Pictures/shiny"), 2, 134])
#     end
#     # Draw all images
#     pbDrawImagePositions(overlay, imagepos)
#     # Write various bits of text
#     pagename = [_INTL("INFO"),
#                 _INTL("TRAINER MEMO"),
#                 _INTL("SKILLS"),
#                 _INTL("MOVES"),
#                 _INTL("MOVES")][page - 1]
#     textpos = [
#       [pagename, 26, 10, 0, base, shadow],
#       [@pokemon.name, 46, 56, 0, base, shadow],
#       [@pokemon.level.to_s, 46, 86, 0, Color.new(64, 64, 64), Color.new(176, 176, 176)],
#       [_INTL("Item"), 66, 312, 0, base, shadow]
#     ]
#     # Write the held item's name
#     if @pokemon.hasItem?
#       textpos.push([@pokemon.item.name, 16, 346, 0, Color.new(64, 64, 64), Color.new(176, 176, 176)])
#     else
#       textpos.push([_INTL("None"), 16, 346, 0, Color.new(192, 200, 208), Color.new(208, 216, 224)])
#     end
#     # Write the gender symbol
#     if @pokemon.male?
#       textpos.push([_INTL("♂"), 178, 56, 0, Color.new(24, 112, 216), Color.new(136, 168, 208)])
#     elsif @pokemon.female?
#       textpos.push([_INTL("♀"), 178, 56, 0, Color.new(248, 56, 32), Color.new(224, 152, 144)])
#     end
#     # Draw all text
#     pbDrawTextPositions(overlay, textpos)
#     # Draw the Pokémon's markings
#     drawMarkings(overlay, 84, 292)
#     # Draw page-specific information
#     case page
#     when 1 then
#       drawPageOne
#     when 2 then
#       drawPageTwo
#     when 3 then
#       drawPageThree
#     when 4 then
#       drawPageFour
#     when 5 then
#       drawPageFive
#     end
#   end
# end