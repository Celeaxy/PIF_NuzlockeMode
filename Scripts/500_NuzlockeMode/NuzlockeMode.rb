module NuzlockeMode
  class << self
    attr_accessor :active
  end

  def self.active?
    self.active.to_s == 'true'
  end
end

# Can be swapped for a switch
SaveData.register(:nuzlockeMode_active) do
  save_value { NuzlockeMode.active? }
  load_value { |value| NuzlockeMode.active = value }
  new_game_value { false }
end

$nuzlockeMode_NewGame = false
module Game
  $nuzlockeMode_original_start_new = self.method(:start_new)

  def self.start_new(ngp_bag = nil, ngp_storage = nil, ngp_trainer = nil)
    selectedOption = 1
    loop do
      selectedOption = pbMessage(_INTL("Would you like to enable Nuzlocke?"), ["Yes", "No", "More Info"])
      if selectedOption == 2
        pbMessage(_INTL("A Nuzlocke is a challenge, intended to create a unique and more challenging gameplay experience through a set of rules."))
        next
      end
      break
    end
    $nuzlockeMode_original_start_new.call(ngp_bag, ngp_storage, ngp_trainer)
    NuzlockeMode.active = selectedOption == 0 # Yes
    $nuzlockeMode_NewGame = true
  end
end


$nuzlockeMode_original_CharacterSelectionMenuView = CharacterSelectionMenuView.public_instance_method(:start)
class CharacterSelectionMenuView
  def start
    $nuzlockeMode_NewGame = false
    #@presenter.nuzlockeMode_ShowTrainerClothes
    $nuzlockeMode_original_CharacterSelectionMenuView.bind(self).call
  end
end

$nuzlockeMode_original_TrainerClothesPreviewShow = TrainerClothesPreview.public_instance_method(:show)
class TrainerClothesPreview
  def show
    return if $nuzlockeModeNewGame
    $nuzlockeMode_original_TrainerClothesPreviewShow.bind(self).call
  end
end

class CharacterSelectMenuPresenter
  def nuzlockeMode_ShowTrainerClothes
    @trainerPreview.show()
  end
end

class Player
  attr_accessor :nuzlocke
  alias_method :original_initialize, :initialize
  def initialize(name, trainer_type)
    original_initialize(name, trainer_type)
    @nuzlocke = NuzlockeMode.active? # TODO: Might cause bug of not saving NuzlockeMode
  end

end