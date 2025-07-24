# 🧝 simple-quest 🧝
Two examples of code: .lua and .rbxm formats.

# COPYRIGHT
PLEASE INSERT THIS IF YOU WILL MODIFICATE STANDART API.

SimpleQuest is a Knit based service writted by Larsen-dev. All modifications are welcomed.

# Important
GroupService was not a serious project, just a practise, so if you find any problems please connect me.

# 📌 Short API description 📌
@class Quest
  - :configureReward(self: Quest, rewardHandler: (questMembers: {  Player  }) -> ()) -> ()
  - :configureObjective(self: Quest, objective: "Touch" | "Collect" | "Kill" | "Custom", goals: {  [number]: Part | MeshPart | Tool | Humanoid | any  }, objectiveHandler: (plusCountHandler: () -> ()) -> ()?) -> ()
  - :cancel(self: Quest) -> ()

@service SimpleQuest
  - :CreateQuest(self: SimpleQuest, players: {  Player  }, description: string) -> (quest: Quest)
  - :GetQuestFromId(self: SimpleQuest, id: number, client: boolean) -> (quest: Quest | nil)
  - Client:GetQuestDataFromId(self: SimpleQuest, player: Player, id: number) -> (quest: Quest | nil)

Dependecies:
  - Promise ^latest
  - Knit ^latest
