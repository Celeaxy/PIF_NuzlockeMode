class PokemonPartyPanel
  alias_method :original_initialize, :initialize

  def initialize(pokemon, index, viewport = nil)
    original_initialize(pokemon, index, viewport)
    @statuses = AnimatedBitmap.new(_INTL("Data/NuzlockeMode_Data/statuses")) if NuzlockeMode.active?
  end
  
  def refresh
    return if disposed?
    return if @refreshing
    @refreshing = true
    if @panelbgsprite && !@panelbgsprite.disposed?
      if self.selected
        if self.preselected;
          @panelbgsprite.changeBitmap("swapsel2")
        elsif @switching;
          @panelbgsprite.changeBitmap("swapsel")
        elsif @pokemon.fainted?;
          @panelbgsprite.changeBitmap("faintedsel")
        else
          ; @panelbgsprite.changeBitmap("ablesel")
        end
      else
        if self.preselected;
          @panelbgsprite.changeBitmap("swap")
        elsif @pokemon.fainted?;
          @panelbgsprite.changeBitmap("fainted")
        else
          ; @panelbgsprite.changeBitmap("able")
        end
      end
      @panelbgsprite.x = self.x
      @panelbgsprite.y = self.y
      @panelbgsprite.color = self.color
    end
    if @hpbgsprite && !@hpbgsprite.disposed?
      @hpbgsprite.visible = (!@pokemon.egg? && !(@text && @text.length > 0))
      if @hpbgsprite.visible
        if self.preselected || (self.selected && @switching);
          @hpbgsprite.changeBitmap("swap")
        elsif @pokemon.fainted?;
          @hpbgsprite.changeBitmap("fainted")
        else
          ; @hpbgsprite.changeBitmap("able")
        end
        @hpbgsprite.x = self.x + 96
        @hpbgsprite.y = self.y + 50
        @hpbgsprite.color = self.color
      end
    end
    if @ballsprite && !@ballsprite.disposed?
      @ballsprite.changeBitmap((self.selected) ? "sel" : "desel")
      @ballsprite.x = self.x + 10
      @ballsprite.y = self.y
      @ballsprite.color = self.color
    end
    if @pkmnsprite && !@pkmnsprite.disposed?
      @pkmnsprite.x = self.x + 60
      @pkmnsprite.y = self.y + 40
      @pkmnsprite.color = self.color
      @pkmnsprite.selected = self.selected
    end
    if @helditemsprite && !@helditemsprite.disposed?
      if @helditemsprite.visible
        @helditemsprite.x = self.x + 62
        @helditemsprite.y = self.y + 48
        @helditemsprite.color = self.color
      end
    end
    if @overlaysprite && !@overlaysprite.disposed?
      @overlaysprite.x = self.x
      @overlaysprite.y = self.y
      @overlaysprite.color = self.color
    end
    if @refreshBitmap
      @refreshBitmap = false
      @overlaysprite.bitmap.clear if @overlaysprite.bitmap
      basecolor = Color.new(248, 248, 248)
      shadowcolor = Color.new(40, 40, 40)
      pbSetSystemFont(@overlaysprite.bitmap)
      textpos = []
      # Draw Pokémon name
      textpos.push([@pokemon.name, 96, 10, 0, basecolor, shadowcolor])
      if !@pokemon.egg?
        if !@text || @text.length == 0
          # Draw HP numbers
          textpos.push([sprintf("% 3d /% 3d", @pokemon.hp, @pokemon.totalhp), 224, 54, 1, basecolor, shadowcolor])
          # Draw HP bar
          if @pokemon.hp > 0
            w = @pokemon.hp * 96 * 1.0 / @pokemon.totalhp
            w = 1 if w < 1
            w = ((w / 2).round) * 2
            hpzone = 0
            hpzone = 1 if @pokemon.hp <= (@pokemon.totalhp / 2).floor
            hpzone = 2 if @pokemon.hp <= (@pokemon.totalhp / 4).floor
            hprect = Rect.new(0, hpzone * 8, w, 8)
            @overlaysprite.bitmap.blt(128, 52, @hpbar.bitmap, hprect)
          end
          # Draw status
          status = 0
          if @pokemon.fainted?
            status = NuzlockeMode.active? ? GameData::Status.get(:DEAD).id_number : 6
          elsif @pokemon.status != :NONE
            status = GameData::Status.get(@pokemon.status).id_number
          elsif @pokemon.pokerusStage == 1
            status = GameData::Status.get(:POKERUS).id_number
          end
          status -= 1
          if status >= 0
            statusrect = Rect.new(0, 16 * status, 44, 16)
            @overlaysprite.bitmap.blt(78, 68, @statuses.bitmap, statusrect)
          end
        end
        # Draw gender symbol
        if @pokemon.male?
          textpos.push([_INTL("♂"), 224, 10, 0, Color.new(0, 112, 248), Color.new(120, 184, 232)])
        elsif @pokemon.female?
          textpos.push([_INTL("♀"), 224, 10, 0, Color.new(232, 32, 16), Color.new(248, 168, 184)])
        end
        # Draw shiny icon
        if @pokemon.shiny?
          imagePos = []
          addShinyStarsToGraphicsArray(imagePos, 80, 48, @pokemon.bodyShiny?, @pokemon.headShiny?, @pokemon.debugShiny?, 0, 0, 16, 16)
          pbDrawImagePositions(@overlaysprite.bitmap, imagePos)
        end
      end
      pbDrawTextPositions(@overlaysprite.bitmap, textpos)
      # Draw level text
      if !@pokemon.egg?
        pbDrawImagePositions(@overlaysprite.bitmap, [[
                                                       "Graphics/Pictures/Party/overlay_lv", 20, 70, 0, 0, 22, 14]])
        pbSetSmallFont(@overlaysprite.bitmap)
        pbDrawTextPositions(@overlaysprite.bitmap, [
          [@pokemon.level.to_s, 42, 57, 0, basecolor, shadowcolor]
        ])
      end
      # Draw annotation text
      if @text && @text.length > 0
        pbSetSystemFont(@overlaysprite.bitmap)
        pbDrawTextPositions(@overlaysprite.bitmap, [
          [@text, 96, 52, 0, basecolor, shadowcolor]
        ])
      end
    end
    @refreshing = false
  end
end