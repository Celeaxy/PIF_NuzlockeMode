# Prevent items from being used in battles
class PokeBattle_Battle
  alias_method :original_pbCanUseItemOnPokemon?, :pbCanUseItemOnPokemon?
  def pbCanUseItemOnPokemon?(item,pkmn,battler,scene,showMessages=true)
    ret = original_pbCanUseItemOnPokemon?(item, pkmn, battler, scene, showMessages)
    if ret && NuzlockeMode.active?
      scene.pbDisplay(_INTL("Can't use items in battle!")) if showMessages
      return false
    end
    ret
  end
end