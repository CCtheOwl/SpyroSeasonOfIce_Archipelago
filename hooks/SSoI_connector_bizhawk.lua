

DEBUG = false



--I want a banana.

--CCtheOwl 9/25/2026




--TODO:
--Make keys into items/locations.
--Write a script that detects when Spyro picks up a gem, then logs which one was picked up (IWRAM address), and where it was picked up at (Spyro XYZ coordinates). Then collect every gem, and use the results to make gemsanity.
--Add an option to YAML that makes it so that receiving an item doesn't give you the item, it enables you to go get it. Then make teleporting between unlocked levels available at the start of the game. That way, players must warp between levels all willy-nilly. Fun!
--Make portals to levels into items that must be received before the portal can be used. Some portals are always unlocked though...I don't think I could do those without ROM hacking, so this is further down on my list.
--Allow Lua to reconnect to Client if Client stalls.






--Begin Spyro: Season of Ice logic module.


--[[
Combined WRAM
-------------------

0x041422 0x041423 - Autumn Fairy Home Atlas gem count.

0x031B60 - How many gems the HUD says you have.
]]

--[[
EWRAM
--------------------

0x031E49 - Can be changed to adjust how many fairies the HUD says you have. Separate from how many fairies the portals think you have.


 



0x032408/0x032409 - The non-isometric X/Y position of that red gem that's on that green grass square up the first ledge to the Northeast of where you spawn in initially in Autumn Fairy Home.

0x032422 - Whether that gem^^^ was picked up or not. 0 = not picked up, 1 = picked up and won't spawn back, 2 = being dragged towards Spyro.

0x034E05 - Mirror of whether the gem at the water's edge to the West of where you spawn in initially in Autumn Fairy Home has been picked up or not.

This info only pertains to Autumn Fairy Home gems, mostly.
Gems stored as 92-byte objects, with 32 bytes of space between each gem.
The 15th byte is the gem identifier. The value this byte holds is how the game knows what gem you just picked up, to check it off its list. Changing this byte to an identifier that doesn't exist results in Spyro being removed a few frames after the gem is picked up.
The 53rd, 54th, 57th, 58th, 61st and 62nd byte all seeem to be related to the gem's X Y (Z?) position.
The 29th and 30th byte is Spyro's non-isometric X position relative to the gem's splash effect following gem pickup. Only adjusts while the gem or splash is within render distance, and only updates until the splash sprite is removed.
The 31st and 32nd byte are the above but for Y.
The 73rd and 74th byte are the above but for X for the gem itself, ceasing adjustment as soon as the gem is picked up.
The 75th and 76th byte are the above but for Y for the gem itself.
The 33rd byte is an alt-frame mirror of the 49th byte.
The 49th byte indicates one of 16 directions that the gem could be facing, from 00 to 0F.
The 50th byte is the timer for when the gem should change direction. The value is constantly decrementing by 1 while the gem is within render distance. When the value hits 0, it jumps up to 3 on the next frame. Two frames after the value hits 0, the 49th and 33rd byte increment by 1. Freezing this value to 00 makes the gem's direction increment on every frame.

Pickup:
Immediately after picking the gem up, the 15th byte changes to FF, byte 25 and 26 increase by 12888?, the 29th byte increases by 9, the 37th byte has its 7th bit engaged, the 41st byte has its 4th bit engaged, the 43rd byte decreases by 5, the 53rd and 54th byte increment by 30XX while Sparx is dragging the gem (XX being the distance the gem is pulled towards Spyro?) and stops changing when Spyro touches and picks it up, so does the 57th and 58th byte, so does the 61st and 62nd byte, the 83rd byte changes from 00 to 02 when Sparx picks the gem up and maintains that while dragging it then decreases it from 02 to 01 when Spyro touches and picks the gem up and maintains that value, and the last two bytes - 91 and 92 - go from 00 00 to 01 01, then one frame later, the 92nd byte goes to 02.
Several frames after pickup, about 3 frames until the gem splash disappears, the first two bytes increase by a number which is only consistent for the specific gem that was picked up, the 13th byte has its 8th bit engaged, the 17th byte has all bits engaged, the 18th byte has bit 1 engaged, the 49th byte and the 33rd byte come to rest at 0A while the 50th byte comes to rest at 05.
]]

--[[
IWRAM
--------------------
]]

--[[
0x1C6E - The...viewable position Spyro's in within the given chunk...???

0x1C88 - The direction Spyro is facing or moving, from 00 (straight up) to 0F (straight up and slightly left). Freezing this forces Spyro to go in a straight line. 

0x1C60 thru 0x1C63 - Spyro's isometric X position minus 1. Don't think I can do anything with these...
0x1C64 thru 0x1C67 - Spyro's isometric Y position minus 1.
0x1C68 thru 0x1C6B - Mirror of the height of the cliff Spyro's shadow is touching. 00000000 is water. 00006400 is one up from that. 0000C400 is two up from that.
]]
--[[
0x1C6C thru 0x1C6F - Spyro's isometric X position. I can definitely do stuff with these...~
]] IWRAM_SPYROXCOORDINATE = 0x1C6C
--[[
0x1C70 thru 0x1C73 - Spyro's isometric Y position.
]] IWRAM_SPYROYCOORDINATE = 0x1C70
--[[
0x1C74 thru 0x1C77 - Spyro's Z position. 00000000 is water. 00006400 is one up from that. 0000C400 is two up from that.
]] IWRAM_SPYROZCOORDINATE = 0x1C74
--[[
0x1C80 thru 0x1C83 - Spyro's Z axis velocity. 00000XXX those values indicate the speed. XXXXX000 those values indicate the direction, with 00000 being skywards and FFFFF being ground-wards. Freezing this prevents Spyro from going up when jumping...but makes him hover slowly to the ground while falling.

0x1C7C thru 0x1C7F - Freezing this takes away most of the player's ability to control Spyro while he's mid-air. It kinda plays like Mario 1...

0x1C8A 0x1C8B - Spyro's idle animation timer or something. Freezing this makes Spyro move really jaggedly as his animations are no longer smoothly reset to neutral between actions lol.
]]

--[[
0x1436 - Ant Farm Atlas unsigned gem count
]]

--[[
0x1120
bit 1 - Gabrielle - Autumn Fairy Home 230 120 2 - Explorer
bit 2 - Torrie - Autumn Fairy Home 200 -8 2 - Explorer
bit 4 - Summer - Autumn Fairy Home 100 10 5 - Explorer
bit 8 - Autumn - Autumn Fairy Home 130 -40 5 - Explorer
bit 32 - Grace - Autumn Fairy Home 38 16 5 - Spooker
]] IWRAM_AUTUMNFAIRYHOME_FAIRIES = 0x1120
--[[
0x1140
bit 1 - Irene - Market Mesa 260 18 7 - Choir Director
bit 2 - Grayson - Market Mesa 255 50 5 - Apprehender
bit 4 - Lauren - Market Mesa 78 42 9 - Explorer
bit 8 - Liz - Market Mesa 190 -50 9 - Explorer
bit 16 - Alice - Market Mesa 210 18 16 - Slayer
bit 32 - Marta - Market Mesa 242 134 3 - Thurifer
]] IWRAM_MARKETMESA_FAIRIES = 0x1140
--[[
0x1160
bit 1 - Ali - Lava Prairie 90 50 0 - Hole Plugger
bit 2 - Michelle - Lava Prairie 150 -98 5 - Explorer
bit 4 - Melissa - Lava Prairie 270 16 3 - Explorer
bit 8 - Suzan - Lava Prairie 118 104 0 - Explorer
]] IWRAM_LAVAPRAIRIE_FAIRIES1 = 0x1160
--[[
0x1161
bit 4 - Rhonda - Lava Prairie 188 94 5 - Slayer
bit 8 - Cassandra - Lava Prairie 194 144 0 - Landscaper
]] IWRAM_LAVAPRAIRIE_FAIRIES2 = 0x1161
--[[
0x1180
bit 1 - Rachel - Mermaid Coast 180 -22 0 - Wingman
bit 2 - Amy - Mermaid Coast 206 172 0 - Explorer
bit 4 - Nadia - Mermaid Coast 280 8 0 - Explorer
bit 8 - Kathy - Mermaid Coast 170 -110 0 - Explorer
bit 16 - Anna - Mermaid Coast 280 42 4 - Slayer
bit 32 - Christine - Mermaid Coast 232 76 0 - Castle Crasher
]] IWRAM_MERMAIDCOAST_FAIRIES = 0x1180
--[[
0x11A0
bit 1 - Sam - Stone Age Speedway - Normal
bit 2 - Peaseblossom - Stone Age Speedway - Hard
]] IWRAM_STONEAGESPEEDWAY_FAIRIES = 0X11A0
--[[
0x11C5
bit 4 - Angela - Ant Farm
]] IWRAM_ANTFARM_FAIRY = 0x11C5
--[[
0x11E0
bit 1 - Fiona - Winter Fairy Home 104 80 4 - Explorer
bit 2 - Christy - Winter Fairy Home 228 118 2 - Explorer
bit 4 - Sung - Winter Fairy Home 250 -20 4 - Explorer
bit 8 - Britney - Winter Fairy Home 208 52 4 - Explorer
bit 32 - Cindy - Winter Fairy Home 278 74 1 - Space Heater
]] IWRAM_WINTERFAIRYHOME_FAIRIES = 0x11E0
--[[
0x1200
bit 1 - Coco - Hummingbird Fort 296 18 1 - Liberator
bit 2 - Julie - Hummingbird Fort 144 4 6 - Explorer
bit 4 - Marissa - Hummingbird Fort 164 -46 5 - Explorer
bit 8 - Samantha - Hummingbird Fort 46 38 1 - Explorer
bit 16 - Candace - Hummingbird Fort 246 94 4 - Slayer
bit 32 - Kiki - Hummingbird Fort 296 62 1 - Tinderer
]] IWRAM_HUMMINGBIRDFORT_FAIRIES = 0x1200
--[[
0x1220
bit 1 - Doodle - Panda Gardens 202 84 4 - I'm sorry, your name is DOODLE?
bit 2 - Oi - Panda Gardens 136 118 3 - Explorer
bit 4 - Natalie - Panda Gardens 202 -54 6 - Explorer
bit 8 - Jennie - Panda Gardens 154 -6 0 - Apprehender
bit 16 - Steffi - Panda Gardens 306 30 0 - Slayer
bit 32 - Charlotte - Panda Gardens 176 120 3 - Tomyoer
]] IWRAM_PANDAGARDENS_FAIRIES = 0x1220
--[[
0x1240
bit 1 - Kristen - Honey Marsh 144 -18 0 - Beekeeper
bit 2 - Yaya - Honey Marsh 158 -106 4 - Explorer
bit 4 - Chu Chu - Honey Marsh 142 58 4 - Explorer
bit 8 - Letty - Honey Marsh 338 44 0 - Explorer
bit 16 - Karen - Honey Marsh 160 106 4 - Slayer
bit 32 - Rhiannon - Honey Marsh 232 96 4 - Honey Centrifuger
]] IWRAM_HONEYMARSH_FAIRIES = 0x1240
--[[
0x1260
bit 1 - Liora - Ice Age Speedway - Normal
bit 2 - Naomi - Ice Age Speedway - Hard
]] IWRAM_ICEAGESPEEDWAY_FAIRIES = 0x1260
--[[
0x1285
bit 4 - Jody - Wasp City
]] IWRAM_WASPCITY_FAIRY = 0x1285
--[[
0x12A0
bit 1 - Merriweather - Spring Fairy Home 200 -54 10 - Explorer
bit 2 - Judy - Spring Fairy Home 274 4 6 - Explorer
bit 4 - Heidi - Spring Fairy Home 250 116 2 - Explorer
bit 8 - Tessa - Spring Fairy Home 124 -6 9 - Explorer
bit 32 - Cassie - Spring Fairy Home 238 130 2 - Gardener
]] IWRAM_SPRINGFAIRYHOME_FAIRIES = 0x12A0
--[[
0x12C0
bit 1 - Gladys - Time Machine Lab 184 -88 0 - Sporker
bit 2 - Deborah - Time Machine Lab 140 -80 4 - Explorer
bit 4 - Cookie - Time Machine Lab 70 38 6 - Explorer
bit 8 - Maggie - Time Machine Lab 266 16 6 - Explorer
bit 16 - Xiang - Time Machine Lab 330 40 0 - Slayer
bit 32 - Hollie - Time Machine Lab 98 -50 5 - Pencil Pusher
]] IWRAM_TIMEMACHINELAB_FAIRIES = 0x12C0
--[[
0x12E0
bit 1 - Sarah - Roman City 214 98 0 - Pot Popper
bit 2 - Kim - Roman City 150 -20 0 - Apprehender
bit 4 - Jessie - Roman City 220 -40 3 - Explorer
bit 8 - Nina - Roman City 32 10 3 - Explorer
bit 16 - Doty - Roman City 170 144 3 - Slayer
bit 32 - Laramie - Roman City 50 4 0 - Brazier Lighter
]] IWRAM_ROMANCITY_FAIRIES = 0x12E0
--[[
0x1300
bit 1 - Elizabeth - Twilight Bulb Factory 38 8 2 - Visionary
bit 2 - Blue - Twilight Bulb Factory 130 2 3 - Explorer
bit 4 - Sylvia - Twilight Bulb Factory 254 138 0 - Explorer
bit 8 - Sugarplum - Twilight Bulb Factory 156 -106 2 - Explorer
bit 16 - Callie - Twilight Bulb Factory 76 -38 3 - Explorer
bit 64 - Mab - Twilight Bulb Factory 194 -18 0 - Propeller
]] IWRAM_TWILIGHTBULBFACTORY_FAIRIES = 0x1300
--[[
0x1320
bit 1 - Jo - Aqua Age Speedway - Normal
bit 2 - Betty - Aqua Age Speedway - Hard
]] IWRAM_AQUAAGESPEEDWAY_FAIRIES = 0x1320
--[[
0x1345
bit 4 - Franny - Beetle Burrows
]] IWRAM_BEETLEBURROWS_FAIRY = 0x1345
--[[
0x1360
bit 1 - Glinda - Summer Fairy Home 70 56 9 - Explorer
bit 2 - Penny - Summer Fairy Home 184 12 1 - Explorer
bit 4 - Merritt - Summer Fairy Home 306 16 1 - Explorer
bit 8 - Chi Chi - Summer Fairy Home 182 -92 7 - Explorer
bit 32 - Mellie - Summer Fairy Home 116 -38 9 - Mushroom Knife
]] IWRAM_SUMMERFAIRYHOME_FAIRIES = 0x1360
--[[
0x1380
bit 1 - Alex - Dusty Trails 136 94 5 - Explorer
bit 2 - Sandra - Dusty Trails 195 -46 4 - Explorer
bit 4 - Flavie - Dusty Trails 250 22 5 - Explorer
bit 8 - Carrie - Dusty Trails 260 68 0 - Apprehender
bit 16 - Mariah - Dusty Trails 310 28 0 - Slayer
bit 32 - Eileen - Dusty Trails 64 -32 2 - Midnight Oiler
]] IWRAM_DUSTYTRAILS_FAIRIES = 0x1380
--[[
0x13A0
bit 1 - Tammy - Star Park 202 90 0 - Ground Controller
bit 2 - Ember - Star Park 70 -52 0 - Explorer
bit 4 - Gwen - Star Park 94 26 2 - Explorer
bit 8 - Meg - Star Park 118 -82 2 - Explorer
bit 16 - Beaney - Star Park 266 90 1 - Slayer
bit 32 - Agent 10 - Star Park 142 132 0 - Monster
]] IWRAM_STARPARK_FAIRIES = 0x13A0
--[[
0x13C0
bit 1 - Mustardseed - Space Age Speedway - Normal
bit 2 - Micki - Space Age Speedway - Hard
]] IWRAM_SPACEAGESPEEDWAY_FAIRIES = 0x13C0
--[[
0x13E5
bit 4 - Roxie - Caterpillar Gardens
]] IWRAM_CATERPILLARGARDENS_FAIRY = 0x13E5
--[[
0x1400 
bit 1 - Lisa - Grendor #1
bit 2 - Zoe - Grendor #2 - Goal
]] IWRAM_GRENDORSLAIR_FAIRIES = 0x1400

--[[
0x1420 thru 0x147F - ATLAS ITEMS THAT AFFECT PORTALS INSTANTLY

0x1424 - Market Mesa Fairy Atlas
bit 1 - Whether the level is greyed out in the Atlas or not. Engages when you visit for the first time.
value 3 - 1 fairy
value 5 - 2 fairy
value 7 - 3 fairy
value 9 - 4 fairy
value 11 - 5 fairy
value 13 - 6 fairy
]]

--[[
0x1420 - Autumn Fairy Home Fairy Atlas
]] IWRAM_AUTUMNFAIRYHOME_FAIRYATLAS = 0x1420
--[[
0x1424 - Market Mesa Fairy Atlas
]] IWRAM_MARKETMESA_FAIRYATLAS = 0x1424
--[[
0x1428 - Lava Prairie Fairy Atlas
]] IWRAM_LAVAPRAIRIE_FAIRYATLAS = 0x1428
--[[
0x142C - Mermaid Coast Fairy Atlas
]] IWRAM_MERMAIDCOAST_FAIRYATLAS = 0x142C
--[[
0x1430 - Stone Age Speedway Fairy Atlas
]] IWRAM_STONEAGESPEEDWAY_FAIRYATLAS = 0x1430
--[[
0x1434 - Ant Farm Fairy Atlas
]] IWRAM_ANTFARM_FAIRYATLAS = 0x1434
--[[
0x1438 - Winter Fairy Home Fairy Atlas
]] IWRAM_WINTERFAIRYHOME_FAIRYATLAS = 0x1438
--[[
0x143C - Hummingbird Fort Fairy Atlas
]] IWRAM_HUMMINGBIRDFORT_FAIRYATLAS = 0x143C
--[[
0x1440 - Panda Gardens Fairy Atlas
]] IWRAM_PANDAGARDENS_FAIRYATLAS = 0x1440
--[[
0x1444 - Honey Marsh Fairy Atlas
]] IWRAM_HONEYMARSH_FAIRYATLAS = 0x1444
--[[
0x1448 - Ice Age Speedway Fairy Atlas
]] IWRAM_ICEAGESPEEDWAY_FAIRYATLAS = 0x1448
--[[
0x144C - Wasp City Fairy Atlas
]] IWRAM_WASPCITY_FAIRYATLAS = 0x144C
--[[
0x1450 - Spring Fairy Home Fairy Atlas
]] IWRAM_SPRINGFAIRYHOME_FAIRYATLAS = 0x1450
--[[
0x1454 - Time Machine Lab Fairy Atlas
]] IWRAM_TIMEMACHINELAB_FAIRYATLAS = 0x1454
--[[
0x1458 - Roman City Fairy Atlas
]] IWRAM_ROMANCITY_FAIRYATLAS = 0x1458
--[[
0x145C - Twilight Bulb Factory Fairy Atlas
]] IWRAM_TWILIGHTBULBFACTORY_FAIRYATLAS = 0x145C
--[[
0x1460 - Aqua Age Speedway Fairy Atlas
]] IWRAM_AQUAAGESPEEDWAY_FAIRYATLAS = 0x1460
--[[
0x1478 - Caterpillar Gardens Fairy Atlas
]] IWRAM_CATERPILLARGARDENS_FAIRYATLAS = 0x1478
--[[
0x1468 - Summer Fairy Home Fairy Atlas
]] IWRAM_SUMMERFAIRYHOME_FAIRYATLAS = 0x1468
--[[
0x146C - Dusty Trails Fairy Atlas
]] IWRAM_DUSTYTRAILS_FAIRYATLAS = 0x146C
--[[
0x1470 - Star Park Fairy Atlas
]] IWRAM_STARPARK_FAIRYATLAS = 0x1470
--[[
0x1474 - Space Age Speedway Fairy Atlas
]] IWRAM_SPACEAGESPEEDWAY_FAIRYATLAS = 0x1474
--[[
0x1464 - Beetle Burrows Fairy Atlas
]] IWRAM_BEETLEBURROWS_FAIRYATLAS = 0x1464
--[[
0x147C - Grendor's Lair Fairy Atlas (Unlocked between Winter and Spring but not visible until Summer)
]] IWRAM_GRENDORSLAIR_FAIRYATLAS = 0x147C




--Bitwise functions so I can make sense of my own notes. Note to self: Take better notes. Note. I'm notating my notes down while noting to the ground that I'm noting in my notes in an estimate.
--I like having my own.
function bit1bool (value)
	return value>>0&1
end
function bit2bool (value)
	return value>>1&1
end
function bit4bool (value)
	return value>>2&1
end
function bit8bool (value)
	return value>>3&1
end
function bit16bool (value)
	return value>>4&1
end
function bit32bool (value)
	return value>>5&1
end
function bit64bool (value)
	return value>>6&1
end
function bit128bool (value)
	return value>>7&1
end





--Items and Locations:
MONITORS = {
    {
        name = "Progressive Autumn Fairy Home Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Market Mesa Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Lava Prairie Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Mermaid Coast Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Stone Age Speedway Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_STONEAGESPEEDWAY_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_STONEAGESPEEDWAY_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Ant Farm Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ANTFARM_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_ANTFARM_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Winter Fairy Home Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Hummingbird Fort Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Panda Gardens Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Honey Marsh Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Ice Age Speedway Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ICEAGESPEEDWAY_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_ICEAGESPEEDWAY_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Wasp City Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_WASPCITY_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_WASPCITY_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Spring Fairy Home Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Time Machine Lab Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Roman City Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Twilight Bulb Factory Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Aqua Age Speedway Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_AQUAAGESPEEDWAY_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_AQUAAGESPEEDWAY_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Caterpillar Gardens Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_CATERPILLARGARDENS_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_CATERPILLARGARDENS_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Summer Fairy Home Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Dusty Trails Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Star Park Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_STARPARK_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Space Age Speedway Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SPACEAGESPEEDWAY_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_SPACEAGESPEEDWAY_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Beetle Burrows Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_BEETLEBURROWS_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_BEETLEBURROWS_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
    {
        name = "Progressive Grendor's Lair Fairy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_GRENDORSLAIR_FAIRYATLAS, "IWRAM")
			if ok then return v end
			return nil
		end,
        write_mem = function(value_to_write)	
			local ok, v = pcall(memory.writebyte, IWRAM_GRENDORSLAIR_FAIRYATLAS, value_to_write, "IWRAM")
			if ok then return v end
			return nil
		end,
		client_value = 0
    },
	{
        name = "Gabrielle",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Torrie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Summer",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Autumn",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Grace",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_AUTUMNFAIRYHOME_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Irene",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Grayson",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Lauren",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Liz",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Alice",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then return bit16bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v - 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v + 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Marta",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MARKETMESA_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MARKETMESA_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Ali",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES1, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES1, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Michelle",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES1, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES1, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Melissa",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES1, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES1, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Suzan",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES1, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES1, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES1, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Rhonda",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES2, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES2, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES2, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES2, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES2, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Cassandra",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES2, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES2, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES2, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_LAVAPRAIRIE_FAIRIES2, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_LAVAPRAIRIE_FAIRIES2, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Rachel",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Amy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Nadia",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Kathy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Anna",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then return bit16bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v - 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v + 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Christine",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_MERMAIDCOAST_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_MERMAIDCOAST_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Sam",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_STONEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STONEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_STONEAGESPEEDWAY_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STONEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_STONEAGESPEEDWAY_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Peaseblossom",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_STONEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STONEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_STONEAGESPEEDWAY_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STONEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_STONEAGESPEEDWAY_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Angela",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ANTFARM_FAIRY, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ANTFARM_FAIRY, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_ANTFARM_FAIRY, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ANTFARM_FAIRY, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_ANTFARM_FAIRY, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Fiona",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Christy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Sung",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Britney",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Cindy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WINTERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_WINTERFAIRYHOME_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Coco",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Julie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Marissa",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Samantha",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Candace",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then return bit16bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v - 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v + 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Kiki",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HUMMINGBIRDFORT_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Doodle",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Oi",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Natalie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Jennie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Steffi",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then return bit16bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v - 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v + 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Charlotte",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_PANDAGARDENS_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_PANDAGARDENS_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Kristen",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Yaya",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Chu Chu",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Letty",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Karen",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then return bit16bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v - 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v + 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Rhiannon",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_HONEYMARSH_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_HONEYMARSH_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Liora",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ICEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ICEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_ICEAGESPEEDWAY_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ICEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_ICEAGESPEEDWAY_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Naomi",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ICEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ICEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_ICEAGESPEEDWAY_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ICEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_ICEAGESPEEDWAY_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Jody",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_WASPCITY_FAIRY, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WASPCITY_FAIRY, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_WASPCITY_FAIRY, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_WASPCITY_FAIRY, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_WASPCITY_FAIRY, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Merriweather",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Judy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Heidi",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Tessa",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Cassie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPRINGFAIRYHOME_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Gladys",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Deborah",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Cookie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Maggie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Xiang",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then return bit16bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v - 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v + 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Hollie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TIMEMACHINELAB_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TIMEMACHINELAB_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Sarah",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Kim",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Jessie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Nina",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Doty",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then return bit16bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v - 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v + 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Laramie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_ROMANCITY_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_ROMANCITY_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Elizabeth",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Blue",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Sylvia",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Sugarplum",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Callie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then return bit16bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v - 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v + 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Mab",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then return bit64bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit64bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v - 64, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, "IWRAM")
			if ok then 
				if bit64bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_TWILIGHTBULBFACTORY_FAIRIES, v + 64, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Jo",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_AQUAAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AQUAAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_AQUAAGESPEEDWAY_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AQUAAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_AQUAAGESPEEDWAY_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Betty",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_AQUAAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AQUAAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_AQUAAGESPEEDWAY_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_AQUAAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_AQUAAGESPEEDWAY_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Franny",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_BEETLEBURROWS_FAIRY, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_BEETLEBURROWS_FAIRY, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_BEETLEBURROWS_FAIRY, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_BEETLEBURROWS_FAIRY, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_BEETLEBURROWS_FAIRY, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Glinda",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Penny",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Merritt",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Chi Chi",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Mellie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SUMMERFAIRYHOME_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Alex",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Sandra",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Flavie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Carrie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Mariah",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then return bit16bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v - 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v + 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Eileen",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_DUSTYTRAILS_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_DUSTYTRAILS_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Tammy",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Ember",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Gwen",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Meg",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then return bit8bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v - 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit8bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v + 8, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Beaney",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then return bit16bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v - 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit16bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v + 16, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Agent 10",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then return bit32bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v - 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_STARPARK_FAIRIES, "IWRAM")
			if ok then 
				if bit32bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_STARPARK_FAIRIES, v + 32, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Mustardseed",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SPACEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPACEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPACEAGESPEEDWAY_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPACEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPACEAGESPEEDWAY_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Micki",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_SPACEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPACEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPACEAGESPEEDWAY_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_SPACEAGESPEEDWAY_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_SPACEAGESPEEDWAY_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Roxie",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_CATERPILLARGARDENS_FAIRY, "IWRAM")
			if ok then return bit4bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_CATERPILLARGARDENS_FAIRY, "IWRAM")
			if ok then 
				if bit4bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_CATERPILLARGARDENS_FAIRY, v - 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_CATERPILLARGARDENS_FAIRY, "IWRAM")
			if ok then 
				if bit4bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_CATERPILLARGARDENS_FAIRY, v + 4, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Lisa",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_GRENDORSLAIR_FAIRIES, "IWRAM")
			if ok then return bit1bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_GRENDORSLAIR_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_GRENDORSLAIR_FAIRIES, v - 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_GRENDORSLAIR_FAIRIES, "IWRAM")
			if ok then 
				if bit1bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_GRENDORSLAIR_FAIRIES, v + 1, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
	{
        name = "Zoe",
        read_mem = function()	
			local ok, v = pcall(memory.readbyte, IWRAM_GRENDORSLAIR_FAIRIES, "IWRAM")
			if ok then return bit2bool(v) end
			return nil
		end,
        disengage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_GRENDORSLAIR_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 1 then
					local ok2 = pcall(memory.writebyte, IWRAM_GRENDORSLAIR_FAIRIES, v - 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        engage_bit = function()
			local ok, v = pcall(memory.readbyte, IWRAM_GRENDORSLAIR_FAIRIES, "IWRAM")
			if ok then 
				if bit2bool(v) == 0 then
					local ok2 = pcall(memory.writebyte, IWRAM_GRENDORSLAIR_FAIRIES, v + 2, "IWRAM")
					if ok2 then return true end
				end
			end
			return nil
		end,
        send_location = 0,
        location_sent = 0,
        prev_state = 0,
		victory = true,
        check_fn = function(old, new)
            return old ~= nil and new > old
        end
    },
}












































































































































































































































































































































































































































































































--Good stuff





--This compiles the current values of everything. Useful for when we're checking if values changed.
function init()
	print("ya")
	for _, mon in ipairs(MONITORS) do
        local v = mon.read_mem()
        if v ~= nil then
            mon.prev_state = v
        end
    end
end



--Okay so just for some context, I did this because the Japanese release of this game shows you a map of the whole level when you press select.
--International versions of the game, such as English, doesn't do that...and I don't have a Japanese copy of the game to splice International copies with.
--Coordinates that players can use to tell where the heck they've been are the next best thing!
--They've certainly made testing much easier. Wish I had some maps though.
function display_coordinates()
	local function fixed_20_12(addr)
		local v = memory.read_s32_le(addr, "IWRAM")
		return v / 4096 --Converting signed 32 bit to 20.12 fixed point to make it frickin' readable.
	end
	
	local x = math.floor(fixed_20_12(IWRAM_SPYROXCOORDINATE))
	local y = math.floor(fixed_20_12(IWRAM_SPYROYCOORDINATE))
	local z = math.floor(fixed_20_12(IWRAM_SPYROZCOORDINATE) / 6) --Dividing by 6 to make each step up be a direct iteration of 1.
	
	gui.text(2, 2, string.format("X: %i Y: %i Z: %i", x, y, z)) --Draw it in the top left corner of the emulator play screen. I'm kinda proud of this.
end



--Who out here collecting they fairy?
function got_fairy(mon, current_value)
	if mon.location_sent == 0 then
		if mon.check_fn(mon.prev_state, current_value) then
			mon.send_location = 1
		end
	end
end



--This gets run every frame we're connected to Client.
function update()
	display_coordinates()
	local checks_found = {}
    for _, mon in ipairs(MONITORS) do
        local current_value = mon.read_mem()
		
		local IsMonProgressive = string.find(mon.name, "Progressive") --Check for progressive so monitors without client_value don't complain.
		if IsMonProgressive ~= nil then --If we got Progressive in the name...
			if current_value ~= mon.client_value then
				mon.write_mem(mon.client_value) --...Set fairies every frame cuz lazy.
			end
		end
		
		if IsMonProgressive == nil then
			got_fairy(mon, current_value) --Check if the player got any fairies.
		end
	
        if mon.send_location == 1 then --Sending location checks.
			table.insert(checks_found, mon.name) --...append the name of the monitored address to the list of checks to send to Client.
            mon.location_sent = 1 --Track what we're at now with this monitored address.
        end
		
		if mon.name == "Zoe" then --Goal detection.				
			if mon.read_mem() == 1 then
				mon.send_location = 1
				for _, mon2 in ipairs(MONITORS) do
					if mon2.name == "Progressive Grendor's Lair Fairy" then
						mon2.client_value = 5 --Make sure the game recognizes that the player has 100 fairies...in case they want to play Dragonfly X.
					end
				end
			end
		end
		
    end
    return checks_found --Send the list of acquired checks this frame back to main().
end






























































































































































































































































































































































































--Begin base64.lua


-- This file originates from this repository: https://github.com/iskolbin/lbase64
-- It was modified to translate between base64 strings and lists of bytes instead of base64 strings and strings.

package.preload["base64"] = function()
	local base64 = {}
	local extract = _G.bit32 and _G.bit32.extract -- Lua 5.2/Lua 5.3 in compatibility mode
	if not extract then
		if _G._VERSION == "Lua 5.4" then
			extract = load[[return function( v, from, width )
				return ( v >> from ) & ((1 << width) - 1)
			end]]()
		elseif _G.bit then -- LuaJIT
			local shl, shr, band = _G.bit.lshift, _G.bit.rshift, _G.bit.band
			extract = function( v, from, width )
				return band( shr( v, from ), shl( 1, width ) - 1 )
			end
		elseif _G._VERSION == "Lua 5.1" then
			extract = function( v, from, width )
				local w = 0
				local flag = 2^from
				for i = 0, width-1 do
					local flag2 = flag + flag
					if v % flag2 >= flag then
						w = w + 2^i
					end
					flag = flag2
				end
				return w
			end
		end
	end


	function base64.makeencoder( s62, s63, spad )
		local encoder = {}
		for b64code, char in pairs{[0]='A','B','C','D','E','F','G','H','I','J',
			'K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y',
			'Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n',
			'o','p','q','r','s','t','u','v','w','x','y','z','0','1','2',
			'3','4','5','6','7','8','9',s62 or '+',s63 or'/',spad or'='} do
			encoder[b64code] = char:byte()
		end
		return encoder
	end

	function base64.makedecoder( s62, s63, spad )
		local decoder = {}
		for b64code, charcode in pairs( base64.makeencoder( s62, s63, spad )) do
			decoder[charcode] = b64code
		end
		return decoder
	end

	local DEFAULT_ENCODER = base64.makeencoder()
	local DEFAULT_DECODER = base64.makedecoder()

	local char, concat = string.char, table.concat

	function base64.encode( arr, encoder )
		encoder = encoder or DEFAULT_ENCODER
		local t, k, n = {}, 1, #arr
		local lastn = n % 3
		for i = 1, n-lastn, 3 do
			local a, b, c = arr[i], arr[i + 1], arr[i + 2]
			local v = a*0x10000 + b*0x100 + c
			local s
			s = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
			t[k] = s
			k = k + 1
		end
		if lastn == 2 then
			local a, b = arr[n-1], arr[n]
			local v = a*0x10000 + b*0x100
			t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[64])
		elseif lastn == 1 then
			local v = arr[n]*0x10000
			t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[64], encoder[64])
		end
		return concat( t )
	end

	function base64.decode( b64, decoder )
		decoder = decoder or DEFAULT_DECODER
		local pattern = '[^%w%+%/%=]'
		if decoder then
			local s62, s63
			for charcode, b64code in pairs( decoder ) do
				if b64code == 62 then s62 = charcode
				elseif b64code == 63 then s63 = charcode
				end
			end
			pattern = ('[^%%w%%%s%%%s%%=]'):format( char(s62), char(s63) )
		end
		b64 = b64:gsub( pattern, '' )
		local t, k = {}, 1
		local n = #b64
		local padding = b64:sub(-2) == '==' and 2 or b64:sub(-1) == '=' and 1 or 0
		for i = 1, padding > 0 and n-4 or n, 4 do
			local a, b, c, d = b64:byte( i, i+3 )
			local s
			local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
			table.insert(t,extract(v,16,8))
			table.insert(t,extract(v,8,8))
			table.insert(t,extract(v,0,8))
		end
		if padding == 1 then
			local a, b, c = b64:byte( n-3, n-1 )
			local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
			table.insert(t,extract(v,16,8))
			table.insert(t,extract(v,8,8))
		elseif padding == 2 then
			local a, b = b64:byte( n-3, n-2 )
			local v = decoder[a]*0x40000 + decoder[b]*0x1000
			table.insert(t,extract(v,16,8))
		end
		return t
	end

	return base64
end


--Begin lua_5_3_compat.lua


package.preload["lua_5_3_compat"] = function()
	function bit.rshift(a, b)
	  return a >> b
	end
	function bit.lshift(a, b)
	  return a << b
	end
	function bit.bor(a, b)
	  return a | b
	end
	function bit.band(a, b)
	  return a & b
	end
end


--Begin socket.lua


-----------------------------------------------------------------------------
-- LuaSocket helper module
-- Author: Diego Nehab
-- RCS ID: $Id: socket.lua,v 1.22 2005/11/22 08:33:29 diego Exp $
-----------------------------------------------------------------------------
package.preload["socket"] = function()
	local original_global_env = _ENV
	-----------------------------------------------------------------------------
	-- Declare module and import dependencies
	-----------------------------------------------------------------------------
	local base = _G
	local string = require("string")
	local math = require("math")

	function get_lua_version()
		local major, minor = _VERSION:match("Lua (%d+)%.(%d+)")
		assert(tonumber(major) == 5)
		if tonumber(minor) >= 4 then
			return "5-4"
		end
		return "5-1"
	end

	function get_os()
		local the_os, ext, arch
		if package.config:sub(1,1) == "\\" then
			the_os, ext = "windows", "dll"
			arch = os.getenv"PROCESSOR_ARCHITECTURE"
		else
			-- TODO: macos?
			the_os, ext = "linux", "so"
			arch = "x86_64" -- TODO: read ELF header from /proc/$PID/exe to get arch
		end

		if arch:find("64") ~= nil then
			arch = "x64"
		else
			arch = "x86"
		end

		return the_os, ext, arch
	end

	function get_socket_path()
		local the_os, ext, arch = get_os()
		-- for some reason ./ isn't working, so use a horrible hack to get the pwd
		local pwd = "C:/ProgramData/Archipelago/data/lua"
		return pwd .. "/" .. arch .. "/socket-" .. the_os .. "-" .. get_lua_version() .. "." .. ext
	end
	local lua_version = get_lua_version()
	local socket_path = get_socket_path()
	local socket = assert(package.loadlib(socket_path, "luaopen_socket_core"))()
	local event = event
	-- http://lua-users.org/wiki/ModulesTutorial
	local M = {}
	if setfenv then
		setfenv(1, M) -- for 5.1
	else
		_ENV = M -- for 5.2
	end

	M.socket = socket
	-- Bizhawk <= 2.8 has an issue where resetting the lua doesn't close the socket
	-- ...to get around this, we register an exit handler to close the socket first
	if lua_version == '5-1' then
		local old_udp = socket.udp
		function udp(self)
			s = old_udp(self)
			function close_socket(self)
				s:close()
			end
			event.onexit(close_socket)
			return s
		end
		socket.udp = udp
	end

	-----------------------------------------------------------------------------
	-- Exported auxiliar functions
	-----------------------------------------------------------------------------
	function connect(address, port, laddress, lport)
		local sock, err = socket.tcp()
		if not sock then return nil, err end
		if laddress then
			local res, err = sock:bind(laddress, lport, -1)
			if not res then return nil, err end
		end
		local res, err = sock:connect(address, port)
		if not res then return nil, err end
		return sock
	end

	function bind(host, port, backlog)
		local sock, err = socket.tcp()
		if not sock then return nil, err end
		sock:setoption("reuseaddr", true)
		local res, err = sock:bind(host, port)
		if not res then return nil, err end
		res, err = sock:listen(backlog)
		if not res then return nil, err end
		return sock
	end

	try = socket.newtry()

	function choose(table)
		return function(name, opt1, opt2)
			if base.type(name) ~= "string" then
				name, opt1, opt2 = "default", name, opt1
			end
			local f = table[name or "nil"]
			if not f then base.error("unknown key (".. base.tostring(name) ..")", 3)
			else return f(opt1, opt2) end
		end
	end

	-----------------------------------------------------------------------------
	-- Socket sources and sinks, conforming to LTN12
	-----------------------------------------------------------------------------
	-- create namespaces inside LuaSocket namespace


	sourcet = {}
	sinkt = {}

	BLOCKSIZE = 2048

	sinkt["close-when-done"] = function(sock)
		return base.setmetatable({
			getfd = function() return sock:getfd() end,
			dirty = function() return sock:dirty() end
		}, {
			__call = function(self, chunk, err)
				if not chunk then
					sock:close()
					return 1
				else return sock:send(chunk) end
			end
		})
	end

	sinkt["keep-open"] = function(sock)
		return base.setmetatable({
			getfd = function() return sock:getfd() end,
			dirty = function() return sock:dirty() end
		}, {
			__call = function(self, chunk, err)
				if chunk then return sock:send(chunk)
				else return 1 end
			end
		})
	end

	sinkt["default"] = sinkt["keep-open"]

	sink = choose(sinkt)

	sourcet["by-length"] = function(sock, length)
		return base.setmetatable({
			getfd = function() return sock:getfd() end,
			dirty = function() return sock:dirty() end
		}, {
			__call = function()
				if length <= 0 then return nil end
				local size = math.min(socket.BLOCKSIZE, length)
				local chunk, err = sock:receive(size)
				if err then return nil, err end
				length = length - string.len(chunk)
				return chunk
			end
		})
	end

	sourcet["until-closed"] = function(sock)
		local done
		return base.setmetatable({
			getfd = function() return sock:getfd() end,
			dirty = function() return sock:dirty() end
		}, {
			__call = function()
				if done then return nil end
				local chunk, err, partial = sock:receive(socket.BLOCKSIZE)
				if not err then return chunk
				elseif err == "closed" then
					sock:close()
					done = 1
					return partial
				else return nil, err end
			end
		})
	end


	sourcet["default"] = sourcet["until-closed"]

	source = choose(sourcet)
	
	local final_module = M
	
	_ENV = original_global_env

	return final_module
end


--Begin json.lua


--
-- json.lua
--
-- Copyright (c) 2015 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

package.preload["json"] = function()
	-------------------------------------------------------------------------------
	-- Encode
	-------------------------------------------------------------------------------
	local json = { _version = "0.1.0" }
	local encode

	local escape_char_map = {
	  [ "\\" ] = "\\\\",
	  [ "\"" ] = "\\\"",
	  [ "\b" ] = "\\b",
	  [ "\f" ] = "\\f",
	  [ "\n" ] = "\\n",
	  [ "\r" ] = "\\r",
	  [ "\t" ] = "\\t",
	}

	local escape_char_map_inv = { [ "\\/" ] = "/" }
	for k, v in pairs(escape_char_map) do
	  escape_char_map_inv[v] = k
	end


	local function escape_char(c)
	  return escape_char_map[c] or string.format("\\u%04x", c:byte())
	end


	local function encode_nil(val)
	  return "null"
	end 


	local function encode_table(val, stack)
	  local res = {}
	  stack = stack or {}

	  -- Circular reference?
	  if stack[val] then error("circular reference") end

	  stack[val] = true

	  if val[1] ~= nil or next(val) == nil then
		-- Treat as array -- check keys are valid and it is not sparse
		local n = 0
		for k in pairs(val) do
		  if type(k) ~= "number" then
			error("invalid table: mixed or invalid key types")
		  end
		  n = n + 1
		end
		if n ~= #val then
		  error("invalid table: sparse array")
		end
		-- Encode
		for i, v in ipairs(val) do
		  table.insert(res, encode(v, stack))
		end
		stack[val] = nil
		return "[" .. table.concat(res, ",") .. "]"

	  else
		-- Treat as an object
		for k, v in pairs(val) do
		  if type(k) ~= "string" then
			error("invalid table: mixed or invalid key types")
		  end
		  table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
		end
		stack[val] = nil
		return "{" .. table.concat(res, ",") .. "}"
	  end
	end


	local function encode_string(val)
	  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
	end


	local function encode_number(val)
	  -- Check for NaN, -inf and inf
	  if val ~= val or val <= -math.huge or val >= math.huge then
		error("unexpected number value '" .. tostring(val) .. "'")
	  end
	  return string.format("%.14g", val)
	end


	local type_func_map = {
	  [ "nil"     ] = encode_nil,
	  [ "table"   ] = encode_table,
	  [ "string"  ] = encode_string,
	  [ "number"  ] = encode_number,
	  [ "boolean" ] = tostring,
	}


	encode = function(val, stack)
	  local t = type(val)
	  local f = type_func_map[t]
	  if f then
		return f(val, stack)
	  end
	  error("unexpected type '" .. t .. "'")
	end


	function json.encode(val)
	  return ( encode(val) )
	end


	-------------------------------------------------------------------------------
	-- Decode
	-------------------------------------------------------------------------------

	local parse

	local function create_set(...) 
	  local res = {}
	  for i = 1, select("#", ...) do
		res[ select(i, ...) ] = true
	  end
	  return res
	end

	local space_chars   = create_set(" ", "\t", "\r", "\n")
	local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
	local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
	local literals      = create_set("true", "false", "null")

	local literal_map = {
	  [ "true"  ] = true,
	  [ "false" ] = false,
	  [ "null"  ] = nil,
	}


	local function next_char(str, idx, set, negate)
	  for i = idx, #str do
		if set[str:sub(i, i)] ~= negate then
		  return i
		end
	  end
	  return #str + 1
	end


	local function decode_error(str, idx, msg)
	  --local line_count = 1
	  --local col_count = 1
	  --for i = 1, idx - 1 do
	  --  col_count = col_count + 1
	  --  if str:sub(i, i) == "\n" then
	  --   line_count = line_count + 1
	  --    col_count = 1
	  --  end
	  -- end
	  -- emu.message( string.format("%s at line %d col %d", msg, line_count, col_count) )
	end


	local function codepoint_to_utf8(n)
	  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
	  local f = math.floor
	  if n <= 0x7f then
		return string.char(n)
	  elseif n <= 0x7ff then
		return string.char(f(n / 64) + 192, n % 64 + 128)
	  elseif n <= 0xffff then
		return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
	  elseif n <= 0x10ffff then
		return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
						   f(n % 4096 / 64) + 128, n % 64 + 128)
	  end
	  error( string.format("invalid unicode codepoint '%x'", n) )
	end


	local function parse_unicode_escape(s)
	  local n1 = tonumber( s:sub(3, 6),  16 )
	  local n2 = tonumber( s:sub(9, 12), 16 )
	  -- Surrogate pair?
	  if n2 then
		return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
	  else
		return codepoint_to_utf8(n1)
	  end
	end


	local function parse_string(str, i)
	  local has_unicode_escape = false
	  local has_surrogate_escape = false
	  local has_escape = false
	  local last
	  for j = i + 1, #str do
		local x = str:byte(j)

		if x < 32 then
		  decode_error(str, j, "control character in string")
		end

		if last == 92 then -- "\\" (escape char)
		  if x == 117 then -- "u" (unicode escape sequence)
			local hex = str:sub(j + 1, j + 5)
			if not hex:find("%x%x%x%x") then
			  decode_error(str, j, "invalid unicode escape in string")
			end
			if hex:find("^[dD][89aAbB]") then
			  has_surrogate_escape = true
			else
			  has_unicode_escape = true
			end
		  else
			local c = string.char(x)
			if not escape_chars[c] then
			  decode_error(str, j, "invalid escape char '" .. c .. "' in string")
			end
			has_escape = true
		  end
		  last = nil

		elseif x == 34 then -- '"' (end of string)
		  local s = str:sub(i + 1, j - 1)
		  if has_surrogate_escape then 
			s = s:gsub("\\u[dD][89aAbB]..\\u....", parse_unicode_escape)
		  end
		  if has_unicode_escape then 
			s = s:gsub("\\u....", parse_unicode_escape)
		  end
		  if has_escape then
			s = s:gsub("\\.", escape_char_map_inv)
		  end
		  return s, j + 1
		
		else
		  last = x
		end
	  end
	  decode_error(str, i, "expected closing quote for string")
	end


	local function parse_number(str, i)
	  local x = next_char(str, i, delim_chars)
	  local s = str:sub(i, x - 1)
	  local n = tonumber(s)
	  if not n then
		decode_error(str, i, "invalid number '" .. s .. "'")
	  end
	  return n, x
	end


	local function parse_literal(str, i)
	  local x = next_char(str, i, delim_chars)
	  local word = str:sub(i, x - 1)
	  if not literals[word] then
		decode_error(str, i, "invalid literal '" .. word .. "'")
	  end
	  return literal_map[word], x
	end


	local function parse_array(str, i)
	  local res = {}
	  local n = 1
	  i = i + 1
	  while 1 do
		local x
		i = next_char(str, i, space_chars, true)
		-- Empty / end of array?
		if str:sub(i, i) == "]" then 
		  i = i + 1
		  break
		end
		-- Read token
		x, i = parse(str, i)
		res[n] = x
		n = n + 1
		-- Next token 
		i = next_char(str, i, space_chars, true)
		local chr = str:sub(i, i)
		i = i + 1
		if chr == "]" then break end
		if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
	  end
	  return res, i
	end


	local function parse_object(str, i)
	  local res = {}
	  i = i + 1
	  while 1 do
		local key, val
		i = next_char(str, i, space_chars, true)
		-- Empty / end of object?
		if str:sub(i, i) == "}" then 
		  i = i + 1
		  break
		end
		-- Read key
		if str:sub(i, i) ~= '"' then
		  decode_error(str, i, "expected string for key")
		end
		key, i = parse(str, i)
		-- Read ':' delimiter
		i = next_char(str, i, space_chars, true)
		if str:sub(i, i) ~= ":" then
		  decode_error(str, i, "expected ':' after key")
		end
		i = next_char(str, i + 1, space_chars, true)
		-- Read value
		val, i = parse(str, i)
		-- Set
		res[key] = val
		-- Next token
		i = next_char(str, i, space_chars, true)
		local chr = str:sub(i, i)
		i = i + 1
		if chr == "}" then break end
		if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
	  end
	  return res, i
	end


	local char_func_map = {
	  [ '"' ] = parse_string,
	  [ "0" ] = parse_number,
	  [ "1" ] = parse_number,
	  [ "2" ] = parse_number,
	  [ "3" ] = parse_number,
	  [ "4" ] = parse_number,
	  [ "5" ] = parse_number,
	  [ "6" ] = parse_number,
	  [ "7" ] = parse_number,
	  [ "8" ] = parse_number,
	  [ "9" ] = parse_number,
	  [ "-" ] = parse_number,
	  [ "t" ] = parse_literal,
	  [ "f" ] = parse_literal,
	  [ "n" ] = parse_literal,
	  [ "[" ] = parse_array,
	  [ "{" ] = parse_object,
	}


	parse = function(str, idx)
	  local chr = str:sub(idx, idx)
	  local f = char_func_map[chr]
	  if f then
		return f(str, idx)
	  end
	  decode_error(str, idx, "unexpected character '" .. chr .. "'")
	end


	function json.decode(str)
	  if type(str) ~= "string" then
		error("expected argument of type string, got " .. type(str))
	  end
	  return ( parse(str, next_char(str, 1, space_chars, true)) )
	end


	return json
end


--Begin connector_bizhawk_generic.lua
--But I had to change a bunch of stuff so don't expect it to match as closely as the others.


--[[
Copyright (c) 2023 Zunawe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]



--I forget what SCRIPT_VERSION does.
local SCRIPT_VERSION = 1


--BizHawk version check
local bizhawk_version = client.getversion()
local bizhawk_major, bizhawk_minor, bizhawk_patch = bizhawk_version:match("(%d+)%.(%d+)%.?(%d*)")
bizhawk_major = tonumber(bizhawk_major)
bizhawk_minor = tonumber(bizhawk_minor)
if bizhawk_patch == "" then bizhawk_patch = 0 else bizhawk_patch = tonumber(bizhawk_patch) end

--Lua version check
local lua_major, lua_minor = _VERSION:match("Lua (%d+)%.(%d+)")
lua_major = tonumber(lua_major)
lua_minor = tonumber(lua_minor)

--Requires; these pull from the in-lined scripts above.
if lua_major > 5 or (lua_major == 5 and lua_minor >= 3) then
    require("lua_5_3_compat")
end
local base64 = require("base64")
local socket = require("socket")
local json = require("json")

--Client (client) connectivity variables
local SOCKET_PORT_FIRST = 43055 --Lua's port.
local SOCKET_PORT_RANGE_SIZE = 0 --Lua's port can go up by this many if Lua's port is already taken. I've left this at 0 because I don't want to test it. I'll change it if anybody complains.
local SOCKET_PORT_LAST = SOCKET_PORT_FIRST + SOCKET_PORT_RANGE_SIZE --The tallest glass of beer that Lua can drink before Client won't talk to it.
local STATE_NOT_CONNECTED = 0 --An attempt at self-documenting code, I guess. I'm not a fan of not just writing things down, personally.
local STATE_CONNECTED = 1
local server = nil
local client_socket = nil
local current_state = STATE_NOT_CONNECTED
local timeout_timer = 0 --How long to wait between Client heartbeats before Lua stops caring.
local message_timer = 0 --How long between emulator display popups.
local message_interval = 0 --Same as above but for when they get received at the same time?
local prev_time = 0 --I don't know
local current_time = 0
local locked = false --Should Lua be waiting for Client? y/n
local rom_hash = nil --What game we're playing.


--I pretty much left these alone. They help the Client stay connected.
function queue_push (self, value)
    self[self.right] = value
    self.right = self.right + 1
end
function queue_is_empty (self)
    return self.right == self.left
end
function queue_shift (self)
    value = self[self.left]
    self[self.left] = nil
    self.left = self.left + 1
    return value
end
function new_queue ()
    local queue = {left = 1, right = 1}
    return setmetatable(queue, {__index = {is_empty = queue_is_empty, push = queue_push, shift = queue_shift}})
end
local message_queue = new_queue()
function lock ()
    locked = true
    client_socket:settimeout(2)
end
function unlock ()
    locked = false
    client_socket:settimeout(0)
end



--These tell Lua how to interpret words received from Client, and also, tells Lua what to send back to Client.
--I only use PING, WRITE, and DISPLAY_MESSAGE in this APWorld integration.
request_handlers = {
    ["PING"] = function (req) --Sends & receives this every couple seconds to keep Client and Lua connected. It's the heartbeat; Lua checking Client's pulse. It knows it's disconnected when it stops receiving these.
        local res = {}
        res["type"] = "PONG"
        return res
    end,
    ["SYSTEM"] = function (req) --Tells Client what console is being emulated.
        local res = {}
        res["type"] = "SYSTEM_RESPONSE"
        res["value"] = emu.getsystemid()
        return res
    end,
    ["PREFERRED_CORES"] = function (req) --Tells Client what emulator core is being used.
        local res = {}
        local preferred_cores = client.getconfig().PreferredCores
        local systems_enumerator = preferred_cores.Keys:GetEnumerator()
        res["type"] = "PREFERRED_CORES_RESPONSE"
        res["value"] = {}
        while systems_enumerator:MoveNext() do
            res["value"][systems_enumerator.Current] = preferred_cores[systems_enumerator.Current]
        end
        return res
    end,
    ["HASH"] = function (req) --Tells Client what game we're playing. Thanks for playing by the way!
        local res = {}
        res["type"] = "HASH_RESPONSE"
        res["value"] = rom_hash
        return res
    end,
    ["MEMORY_SIZE"] = function (req) --How big we talkin'? Hahaha jokes aside I never use this.
        local res = {}
        res["type"] = "MEMORY_SIZE_RESPONSE"
        res["value"] = memory.getmemorydomainsize(req["domain"])
        return res
    end,
    ["GUARD"] = function (req) --I don't know what this is for.
        local res = {}
        return res
    end,
    ["LOCK"] = function (req) --Client tells Lua, "hey buddy I'm doing something intensive so don't expect a heartbeat for a couple seconds okay?"
        local res = {}
        res["type"] = "LOCKED"
        lock()
        return res
    end,
    ["UNLOCK"] = function (req) --Puts Lua's finger back on Client's pulse.
        local res = {}
        res["type"] = "UNLOCKED"
        unlock()
        return res
    end,
    ["READ"] = function (req) --Client asks to know something about the game, Lua checks the game, Lua sends info back to Client.
		local res = {}
		return res
    end,
    ["WRITE"] = function (req) --Client tells Lua to update the game in some way.

        local res = {}
        res["type"] = "WRITE_RESPONSE"
        local req_item = req["item_name"]
        local bytes_to_write = nil 
		if req["value"] then
			bytes_to_write = base64.decode(req["value"])
        end


		for _, mon in ipairs(MONITORS) do
		
		
			--Handle writing location_sent values.
			if mon.name .. "_location" == req_item then
				mon.location_sent = 1
				mon.engage_bit()
		
			--Handle writing progressives.
			elseif mon.name == req_item then --If Gabrielle == Gabrielle...
				print(mon.name)
				--Extract the value from the table array index.
				local target_val = 0
				if type(bytes_to_write) == "table" then
					target_val = bytes_to_write[1] or 0
				else
					target_val = string.byte(bytes_to_write, 1) or 0
				end

				mon.client_value = target_val
				mon.write_mem(target_val)
				break
					
			end
			
		end

		
		return res
    end,
    ["DISPLAY_MESSAGE"] = function (req) --Client tells Lua to pop a message to the player up on the emulator. Nifty.
        local res = {}
        res["type"] = "DISPLAY_MESSAGE_RESPONSE"
        message_queue:push(req["message"])
        return res
    end,
    ["SET_MESSAGE_INTERVAL"] = function (req) --When Client wants Lua to tell the emulator to tell the player something after a delay. Could be used for sneakysneaky...
        local res = {}
        res["type"] = "SET_MESSAGE_INTERVAL_RESPONSE"
        message_interval = req["value"]
        return res
    end,
    ["default"] = function (req) --CLIENT HELP I DON'T KNOW WHAT THIS IS
        local res = {}
        res["type"] = "ERROR"
        local command_type = req and tostring(req["type"]) or "nil"
        res["err"] = "Unknown command: " .. command_type
        return res
    end,
}
--Tells Lua which of the above words Client just sent it.
function process_request (req)
    if request_handlers[req["type"]] then
        return request_handlers[req["type"]](req)
    else
        return request_handlers["default"](req)
    end
end

--Handling for getting the above words from Client.
function send_receive ()
    client_socket:settimeout(0) --No room for error.
    local message, err = client_socket:receive() --Get the word from Client.

	--Connectivity error handling:
    if err == "timeout" then --What if we don't get the word from Client?
        unlock() --Nothing changes, really. Not here, anyway. Leaving this as a placeholder.
        return
    elseif err == "closed" then --What if war is all over now?
		if current_state == STATE_CONNECTED then
			print("Connection to client closed")
		end

		client_socket:close()
		client_socket = nil
		current_state = STATE_NOT_CONNECTED
		return
    elseif err ~= nil then --Wow I have NO idea what just happened...
        print(err) --Here help me figure this out, chief.
        current_state = STATE_NOT_CONNECTED
        unlock() --Placeholder 2. Unlocktric boogaloo.
        return
    end
    
	
    timeout_timer = 5 --Lua gets 5 seconds to send this next part out.
	
    if message == "VERSION" then --Client sends the VERSION word as the initial handshake, and never again.
        client_socket:send(tostring(SCRIPT_VERSION).."\n") --Oh...here's where SCRIPT_VERSION gets used! It's for Client to know what path to take. Yeah, I don't use that.
    else --If not VERSION, then JSON. 
        local res = {} --Build a response.
        local data = json.decode(message) --What's the content?
        for i, req in ipairs(data) do --For every word Client sent...
			local status, response = pcall(process_request, req) --...run the handling for the word. The handlings can be found above the process_requests() function declaration right up there.
			if status then --If we got status then we got a response to send back to Client from Lua.
				res[i] = response --"This is the response for the first word you sent, which will not be the response for the other word you sent, but I'll send that one too on this next iteration give me a sec."
			else --If you don't have status then I won't talk to you.
				if type(response) ~= "string" then response = "Unknown error" end
				res[i] = {type = "ERROR", err = response}
			end
        end
        client_socket:send(json.encode(res).."\n") --Lua tells Client what it wants to say here. In classic Python format. (Yuck.)
    end
end


--This makes Lua able to be connected to by Client. It uses localhost to stay loopback so it isn't open to LAN or wider.
function initialize_server ()
    local err
    local port = SOCKET_PORT_FIRST --Lua's port.
    local res = nil
    server, err = socket.socket.tcp4() --A socket for my socket.
    while res == nil and port <= SOCKET_PORT_LAST do
        res, err = server:bind("localhost", port) --Try to claim the port.
        if res == nil and err ~= "address already in use" then --If the port is already claimed...
            print(err)
            return
        end
        if res == nil then port = port + 1 end --...try the next one.
    end
    if port > SOCKET_PORT_LAST then --Nothing worked. All ports are claimed.
        print("Too many instances of connector script already running. Exiting.")
        return
    end
    res, err = server:listen(0)
    if err ~= nil then print(err) return end
    server:settimeout(0)
end

function main ()
	init()
    while true do
        if server == nil then initialize_server() end --If no Lua server, Lua server.
		
		--Cooldown times for stuff.
        current_time = socket.socket.gettime()
        timeout_timer = timeout_timer - (current_time - prev_time)
        message_timer = message_timer - (current_time - prev_time)
        prev_time = current_time
        
		--Pop messages to the player up on the emulator.
        if message_timer <= 0 and not message_queue:is_empty() then
            gui.addmessage(message_queue:shift())
            message_timer = message_interval
        end
        
        if current_state == STATE_NOT_CONNECTED then --When we're not connected yet, just try to connect.
            if emu.framecount() % 60 == 0 then
                local client, timeout = server:accept()
                if timeout == nil then
                    print("Client connected")
                    current_state = STATE_CONNECTED
                    client_socket = client
                    server:close()
                    server = nil
                    client_socket:settimeout(0)
				end
            end
        else
			if current_state == STATE_DISCONNECTED then --If Client disconnected from the Lua, panic and freak out.
				print("Client disconnected. Please close BizHawk and re-launch the patchfile to reconnect.")
				message_queue:push("Client disconnected. Please close BizHawk and re-launch the patchfile to reconnect.")
            elseif current_state == STATE_CONNECTED then
                local checked_items = update() --Do so much stuff.
                if #checked_items > 0 then
					--print("there's items in checked_items")
                    for _, item_name in ipairs(checked_items) do
				        for _, mon in ipairs(MONITORS) do
							if item_name == mon.name then --If Gabrielle (check to send) == Gabrielle (the monitor)...
							
								if DEBUG == true then print("[LUA]: " .. mon.name .. " collected!") end
								
								mon.send_location = 0 --Thanks, update(). We got the message, chief.
								
								--Goal location handling.
								if mon.victory then
									local notify = {type = "VICTORY"}
									client_socket:send(json.encode({notify}) .. "\n") --Send VICTORY to Client instead.
								--Regular location handling.
								else
									local notify = {type = mon.name}
									client_socket:send(json.encode({notify}) .. "\n") --...send Gabrielle to Client.
								end
								
								
							end
						end
                    end
                end
            end

            repeat
                send_receive() --I never set locked=true, so this only fires once.
            until not locked
            
            if timeout_timer <= 0 then
                print("Client timed out. Probably didn't receive a heartbeat from it.")
                current_state = STATE_DISCONNECTED
            end
        end
        coroutine.yield() --I have 0 idea what this does. I don't need to know, really. Something to do with making the script run every frame?
    end
end


--Disable the script to see this message and to turn off the localhost Lua loopback server.
event.onexit(function ()
    print("\n-- Script stopped. Please close BizHawk and re-launch the patchfile to reconnect. --\n")
    if server ~= nil then server:close() end
end)


--The top of the chain. Everything fires from here.
if bizhawk_major < 2 or (bizhawk_major == 2 and bizhawk_minor < 7) then
    print("Must use BizHawk 2.7.0 or newer")
else
    if emu.getsystemid() == "NULL" then
        print("No ROM is loaded. Please load a ROM.")
        while emu.getsystemid() == "NULL" do emu.frameadvance() end
    end
    rom_hash = gameinfo.getromhash()
    local co = coroutine.create(main)
    function tick ()
        local success, err = pcall(function() --Lua's equivalent of a try/catch.
            local status, coroutine_err = coroutine.resume(co)
            if not status and coroutine_err ~= "cannot resume dead coroutine" then
                error(coroutine_err)
            end
        end)
        if not success then
            print("oh hey your script died")
            print(err)
        end
    end

    event.onframeend(tick)
    while true do emu.frameadvance() end
end


