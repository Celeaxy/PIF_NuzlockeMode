class PokemonLoadPanel
  alias_method :original_initialize, :initialize

  def initialize(index,title,isContinue,trainer,framecount,mapid,viewport=nil)
    original_initialize(index,title,isContinue,trainer,framecount,mapid,viewport)
    @bgbitmap = AnimatedBitmap.new("Data/NuzlockeMode_Data/loadPanels")
    @refreshBitmap = true
    @refreshing = false
    refresh
  end

  def refresh
    return if @refreshing
    return if disposed?
    @refreshing = true
    panelHeight = 111
    offset = 32
    if !self.bitmap || self.bitmap.disposed?
      self.bitmap = BitmapWrapper.new(@bgbitmap.width,panelHeight*2+offset)
      pbSetSystemFont(self.bitmap)
    end
    if @refreshBitmap
      @refreshBitmap = false
      self.bitmap.clear if self.bitmap
      if @isContinue
        self.bitmap.blt(0,0,@bgbitmap.bitmap,Rect.new(0,(@selected) ? panelHeight*2+offset : 0,@bgbitmap.width,panelHeight*2+offset))
      else
        self.bitmap.blt(0,0,@bgbitmap.bitmap,Rect.new(0,111*2*2+offset*2+((@selected) ? 23*2 : 0),@bgbitmap.width,23*2))
      end
      textpos = []
      if @isContinue
        textpos.push([@title,16*2,2*2,0,TEXTCOLOR,TEXTSHADOWCOLOR])
        textpos.push([_INTL("Badges:"),16*2,53*2,0,TEXTCOLOR,TEXTSHADOWCOLOR])
        textpos.push([@trainer.badge_count.to_s,103*2,53*2,1,TEXTCOLOR,TEXTSHADOWCOLOR])
        
        # textpos.push([_INTL("Pokédex:"),16*2,69*2,0,TEXTCOLOR,TEXTSHADOWCOLOR])
        # textpos.push([@trainer.pokedex.seen_count.to_s,103*2,69*2,1,TEXTCOLOR,TEXTSHADOWCOLOR])

        #textpos.push([_INTL(getDisplayDifficultyFromIndex(@trainer.lowest_difficulty)),16*2,69*2,0,TEXTCOLOR,TEXTSHADOWCOLOR])
        #textpos.push([getGameModeFromIndex(@trainer.game_mode),103*2,69*2,1,TEXTCOLOR,TEXTSHADOWCOLOR])
        textpos.push([_INTL(getDisplayDifficultyFromIndex(@trainer.lowest_difficulty)),16*2,69*2,0,TEXTCOLOR,TEXTSHADOWCOLOR])
        textpos.push([getGameModeFromIndex(@trainer.game_mode),103*2,69*2,1,TEXTCOLOR,TEXTSHADOWCOLOR])
        if @trainer.nuzlocke
          textpos.push([_INTL("Nuzlocke"),16*2,85*2,0,TEXTCOLOR,TEXTSHADOWCOLOR])
        end 
        textpos.push([_INTL("Time:"),16*2,101*2,0,TEXTCOLOR,TEXTSHADOWCOLOR])
        hour = @totalsec / 60 / 60
        min  = @totalsec / 60 % 60
        if hour>0
          textpos.push([_INTL("{1}h {2}m",hour,min),103*2,101*2,1,TEXTCOLOR,TEXTSHADOWCOLOR])
        else
          textpos.push([_INTL("{1}m",min),103*2,101*2,1,TEXTCOLOR,TEXTSHADOWCOLOR])
        end
        if @trainer.male?
          textpos.push([@trainer.name,56*2,29*2,0,MALETEXTCOLOR,MALETEXTSHADOWCOLOR])
        elsif @trainer.female?
          textpos.push([@trainer.name,56*2,29*2,0,FEMALETEXTCOLOR,FEMALETEXTSHADOWCOLOR])
        else
          textpos.push([@trainer.name,56*2,29*2,0,TEXTCOLOR,TEXTSHADOWCOLOR])
        end
        mapname = pbGetMapNameFromId(@mapid)
        mapname.gsub!(/\\PN/,@trainer.name)
        textpos.push([mapname,193*2,2*2,1,TEXTCOLOR,TEXTSHADOWCOLOR])
      else
        textpos.push([@title,16*2,1*2,0,TEXTCOLOR,TEXTSHADOWCOLOR])
      end
      pbDrawTextPositions(self.bitmap,textpos)
    end
    @refreshing = false
  end
end

class PokemonLoad_Scene
  def pbStartScene(commands, show_continue, trainer, frame_count, map_id) 
    @commands = commands
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99998
    addBackgroundOrColoredPlane(@sprites, "background", "loadbg", Color.new(248, 248, 248), @viewport)

    @sprites["leftarrow"] = AnimatedSprite.new("Graphics/Pictures/leftarrow", 8, 40, 28, 2, @viewport)
    @sprites["leftarrow"].x = 10
    @sprites["leftarrow"].y = 140
    @sprites["leftarrow"].play

    #@sprites["leftarrow"].visible=true

    @sprites["rightarrow"] = AnimatedSprite.new("Graphics/Pictures/rightarrow", 8, 40, 28, 2, @viewport)
    @sprites["rightarrow"].x = 460
    @sprites["rightarrow"].y = 140
    @sprites["rightarrow"].play
    #@sprites["rightarrow"].visible=true

    y = 16 * 2
    for i in 0...commands.length
      @sprites["panel#{i}"] = PokemonLoadPanel.new(i, commands[i],
                                                  (show_continue) ? (i == 0) : false, trainer, frame_count, map_id, @viewport)
      @sprites["panel#{i}"].x = 24 * 2
      @sprites["panel#{i}"].y = y
      @sprites["panel#{i}"].pbRefresh
      y += (show_continue && i == 0) ? 112 * 2 + 32 : 24 * 2
    end
    @sprites["cmdwindow"] = Window_CommandPokemon.new([])
    @sprites["cmdwindow"].viewport = @viewport
    @sprites["cmdwindow"].visible = false
  end
end