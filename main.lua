local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ChatService = game:GetService("Chat")

-- Function to ensure that RemoteEvents are created
local function createRemoteEventIfNotExist(eventName)
	if not ReplicatedStorage:FindFirstChild(eventName) then
		local newEvent = Instance.new("RemoteEvent")
		newEvent.Name = eventName
		newEvent.Parent = ReplicatedStorage
		print(eventName .. " created.")
	end
end

-- RemoteEvent setup
createRemoteEventIfNotExist("DiscordCommands")
local DiscordCommands = ReplicatedStorage:WaitForChild("DiscordCommands")

-- Session ID is the unique JobId of the Roblox server
local sessionId = game.JobId
local API_URL = "https://roblox-discord2-api.onrender.com/register-session"  -- Change this to your API URL

-- Create a datastore for banned players (optional, if you want persistence)
local bannedPlayersDataStore = DataStoreService:GetDataStore("BannedPlayers")

-- Register this game session with your external API
local function registerSession()
	local data = {
		sessionId = sessionId,
		playerCount = #Players:GetPlayers(),
		timestamp = os.time()
	}

	-- Log the data to inspect it before sending
	print("Sending data to API:", HttpService:JSONEncode(data))

	local success, response = pcall(function()
		return HttpService:PostAsync(API_URL, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson)
	end)

	if success then
		print("Session registered:", sessionId)
	else
		-- Log more detailed information if the request fails
		print("Failed to register session. Response: ", response)
		warn("Failed to register session:", response)
	end
end

-- Call when the server starts
registerSession()

-- Command handler for DiscordCommands
DiscordCommands.OnServerEvent:Connect(function(player, command, params)
	local args = HttpService:JSONDecode(params)

	-- Log chat message if command is "chat"
	if command == "chat" then
		local message = args[1]
		-- Log the chat in a custom way
		print("[Discord Chat] " .. player.Name .. ": " .. message)
		game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents")
			:WaitForChild("SayMessageRequest"):FireServer("[Discord] " .. player.Name .. ": " .. message, "All")
		-- Handle other commands such as kick, ban, and tp
	elseif command == "kick" then
		local targetPlayerName = args[1]
		local target = Players:FindFirstChild(targetPlayerName)
		if target then
			print("[Command] " .. player.Name .. " kicked " .. target.Name)
			target:Kick("Kicked by admin (via Discord)")
		else
			warn("Player not found: " .. targetPlayerName)
		end
	elseif command == "ban" then
		local targetPlayerName = args[1]
		local target = Players:FindFirstChild(targetPlayerName)
		if target then
			-- Add the player to the banned list (persistent)
			local success, err = pcall(function()
				bannedPlayersDataStore:SetAsync(target.UserId, true)  -- Persist the ban
			end)

			if success then
				print("[Command] " .. player.Name .. " banned " .. target.Name)
				target:Kick("Banned by admin (via Discord)")
			else
				warn("Failed to ban player: " .. err)
			end
		else
			warn("Player not found: " .. targetPlayerName)
		end
	elseif command == "tp" then
		local targetPlayerName = args[1]
		local x = tonumber(args[2])
		local y = tonumber(args[3])
		local z = tonumber(args[4])

		local target = Players:FindFirstChild(targetPlayerName)
		if target and target.Character then
			print("[Command] " .. player.Name .. " teleported " .. targetPlayerName .. " to " .. x .. ", " .. y .. ", " .. z)
			target.Character:MoveTo(Vector3.new(x, y, z))
		else
			warn("Player not found or invalid coordinates for teleport.")
		end
	end
end)
