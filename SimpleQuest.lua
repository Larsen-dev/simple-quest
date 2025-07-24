--[=[
Created by @Larsen264
	--SimpleQuest--
	SimpleQuest is a service used to create and handle quests.
	
	DEPENDECIES:
		- Knit
		- Promise
]=]

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Modules.Knit.Packages.Knit) --Provide valid path to Knit
local Signal = require(Knit.Util.Signal)
local Promise = require(ReplicatedStorage.Modules.Promise) --Provide valid path to Promise

--Quest
local Quest = {}
Quest.__index = Quest

Quest.id = -1
Quest.description = ""
Quest._objective = {}
Quest._players = {}
Quest._rewardHandler = {}
Quest._objectiveHandler = {}
Quest._count = 0
Quest._finalCount = 0
Quest._objectiveConfigured = false
Quest._rewardConfigured = false
Quest.CountAdded = {}
Quest.Configured = {}
Quest.Completed = {}

export type Quest = {
	_objective: string,
	_players: {Player},
	
	CountAdded: Signal.Signal,
	Completed: Signal.Signal,
	Configured: Signal.Signal,
	
	_rewardHandler: () -> (),
	_objectiveHandler: () -> (),
	
	_count: number,
	_finalCount: number,
}

function Quest:configureReward(rewardHandler: (questMembers: {Player}) -> ())
	self._rewardHandler = function()
		Promise.try(function()
			rewardHandler()
		end):catch(warn)
	end
	
	self._rewardConfigured = true
end

function Quest:configureObjective(objective: "Touch" | "Collect" | "Kill" | "Custom", goals: {[number]: Part | MeshPart | Tool | Humanoid | any}, objectiveHandler: (plusCountHandler: () -> ()) -> ()?)
	if not self._rewardConfigured or self._objectiveConfigured then return end
	
	self._finalCount = #goals
	self._objective = objective
	
	if objective == "Touch" then
		self._objectiveHandler = Promise.new(function(resolve, reject, onCancel)
			local touchedConnections: {RBXScriptConnection} = {}
			
			for _, part: Part in ipairs(goals) do
				local touchedConnection: RBXScriptConnection
				touchedConnection = part.Touched:Connect(function(hit)
					if hit.Parent and Promise.try(function()
							Players:GetPlayerFromCharacter(hit.Parent)
						end):await():catch(warn) and table.find(self._players, Players:GetPlayerFromCharacter(hit.Parent)) then
						self._count += 1
						self.CountAdded:Fire(self._count)
						touchedConnection:Disconnect()

						if self._count == self._finalCount then
							resolve()
						end
					end
				end)
				
				table.insert(touchedConnections, touchedConnection)
			end
			
			onCancel(function()
				for _, connection in ipairs(touchedConnections) do
					connection:Disconnect()
				end
			end)
		end)
	elseif objective == "Collect" then
		self._objectiveHandler = Promise.new(function(resolve, reject, onCancel)
			local collectedConnections: {RBXScriptConnection} = {}

			for _, tool: Tool in ipairs(goals) do
				local collectedConnection: RBXScriptConnection
				collectedConnection = tool:GetStyledPropertyChangedSignal("Parent"):Connect(function()
					if tool.Parent and tool.Parent:IsA("Backpack") and table.find(self._players, tool.Parent.Parent) then
						self._count += 1
						self.CountAdded:Fire(self._count)
						collectedConnection:Disconnect()

						if self._count == self._finalCount then
							resolve()
						end
					end
				end)

				table.insert(collectedConnections, collectedConnection)
			end

			onCancel(function()
				for _, connection: RBXScriptConnection in ipairs(collectedConnections) do
					connection:Disconnect()
				end
			end)
		end)
	elseif objective == "Kill" then
		self._objectiveHandler = Promise.new(function(resolve, reject, onCancel)
			local humanoidDiedConnections: {RBXScriptConnection} = {}
			
			for _, humanoid: Humanoid in ipairs(goals) do
				humanoid.HealthChanged:Connect(function()
					if humanoid.Health == 0 then
						self._count += 1
						self.CountAdded:Fire(self._count)
						if self._count == self._finalCount then
							resolve()
						end
					end
				end)
			end
			
			onCancel(function()
				for _, connection: RBXScriptConnection in ipairs(humanoidDiedConnections) do
					connection:Disconnect()
				end
			end)
		end)
	elseif objective == "Custom" then
		self._objectiveHandler = Promise.new(function(resolve, reject)
			objectiveHandler(function()
				self._count += 1
				self.CountAdded:Fire(self._count)
				if self._count == self._finalCount then
					resolve()
				end
			end)
		end)
		
		self._objectiveHandler:catch(function(errorMessage)
			self._objectiveConfigured = false
			self._objectiveHandler = {}
			error(tostring(errorMessage))
		end)
	end
	
	self._objectiveHandler:andThen(function()
		Promise.try(function()
			self.Completed:Fire()

			table.clear(self)
			self = nil
			
			self._rewardHandler()
		end):catch(function(errorMessage)
			error(tostring(errorMessage))
		end)
	end)
	
	self._objectiveConfigured = true
	self.Configured:Fire()
end

function Quest:cancel()
	self._rewardHandler = {}
	
	self._objectiveConfigured = false
	self._objectiveHandler:cancel()
	
	self._objectiveHandler = {}
	
	table.clear(self)
	self = nil
end

--Service
local SimpleQuest = Knit.CreateService {
	Name = "SimpleQuest",
	Client = {
		QuestStarted = Knit.CreateSignal(),
	}
}
SimpleQuest.Quests = {}

function SimpleQuest:CreateQuest(players: {Player}, description: string)
	local quest = setmetatable(Quest, {
		__index = function(_, key)
			error(string.format("%s is not valid member of quest", key))
		end,		
		__newindex = function(_, key, value)
			error("Creating new members don't allowed!")
		end,
	}) :: Quest
	quest._players = players
	quest.description = description
	quest.Completed = Signal.new()
	quest.Configured = Signal.new()
	quest.CountAdded = Signal.new()
	
	table.insert(self.Quests, quest)
	
	quest.id = table.find(self.Quests, quest)
	
	quest.Configured:Once(function()
		for _, player: Player in ipairs(quest._players) do
			self.Client.QuestStarted:Fire(player, quest.id)
		end
	end)
	
	quest.Completed:Once(function()
		table.remove(self.Quests, quest.id)
	end)
	
	return quest
end

function SimpleQuest:GetQuestFromId(id: number, client: boolean)
	print(client)
	
	if client ~= true then return self.Quests[id] end
	
	local quest = self.Quests[id]
	
	local questData = {
		_count = quest._count,
		_finalCount = quest._finalCount,
		description = quest.description,
	}
	
	return questData
end

function SimpleQuest.Client:GetQuestDataFromId(player: Player, id: number)
	return self.Server:GetQuestFromId(id, true)
end

return SimpleQuest