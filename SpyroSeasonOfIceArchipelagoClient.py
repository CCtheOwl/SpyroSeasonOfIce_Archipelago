

#Hi! This is my Client Subclass. It extends CommonContext, from Archipelago's CommonClient.py.
#If you use this in any capacity, reference or copy/paste or whatever, let me know!! It would make me happy to hear it was helpful~ <33

#Happy to answer any questions! Ask them in the game's topic post within the official Archipelago Discord server.

#CCtheOwl 9/27/2026


import asyncio #Turns this into more than just a script! Now it's multithreaded!
import base64 #One of the many fun little ways I format data before sending it to Lua.
import importlib.resources
import json
import os
import shutil
import subprocess
import tempfile
import Utils
import kvui #I know nothing here uses this, but trust me, take this away & Client won't open.
from CommonClient import CommonContext, get_base_parser, gui_enabled, logger, server_loop
from NetUtils import ClientStatus
import Patch #Learning how to use this is nightmarish.


class SSoIContext(CommonContext):
    game = "Spyro Season of Ice"
    items_handling = 0b111 #Archipelago constant. Tells it what to do. You guys couldn't have used like 1 2 3 instead of b00lalala??

    @property #Override the Superclass, CommonContext.
    def suggested_address(self): #Returns the archipelago.gg port you last used, to default into Client's URL textbox.
        storage = Utils.persistent_load() #Todo: test if loading this once is fine, as opposed to loading it in every function I use it in.
        return storage.get("SSoI", {}).get("last_server", super().suggested_address) #I prefer not to use a variable for the storage pointer. The stored value though, I don't care about.

    def __init__(self, server_address: str, password: str):
        super().__init__(server_address, password) #Run the init of the Superclass.

        self.lua_reader = None #This listener will hear output from Lua, mailed directly to Client's doorstep.
        self.lua_writer = None #This listener will write Lua a loveletter and send it straight from here, the Client.
        self.lua_task = None #This listener fires off the lua_to_ap function, and keeps it rolling.
        self.heartbeat_task = None #This listener fires off the heartbeat function, to satisfy Lua, who constantly wants to know if Client is still alive. I just wanted to make sure you haven't died!

        self.location_reminder = 0 #Tell me once, and only once, what we've already sent to Server.
        
        self.ProgressiveAutumnFairyHomeFairy       = 1 
        self.ProgressiveMarketMesaFairy            = 1
        self.ProgressiveLavaPrairieFairy           = 1
        self.ProgressiveMermaidCoastFairy          = 1
        self.ProgressiveStoneAgeSpeedwayFairy      = 1
        self.ProgressiveAntFarmFairy               = 1
        self.ProgressiveWinterFairyHomeFairy       = 1
        self.ProgressiveHummingbirdFortFairy       = 1
        self.ProgressivePandaGardensFairy          = 1
        self.ProgressiveHoneyMarshFairy            = 1
        self.ProgressiveIceAgeSpeedwayFairy        = 1
        self.ProgressiveWaspCityFairy              = 1
        self.ProgressiveSpringFairyHomeFairy       = 1
        self.ProgressiveTimeMachineLabFairy        = 1
        self.ProgressiveRomanCityFairy             = 1
        self.ProgressiveTwilightBulbFactoryFairy   = 1
        self.ProgressiveAquaAgeSpeedwayFairy       = 1
        self.ProgressiveCaterpillarGardensFairy    = 1
        self.ProgressiveSummerFairyHomeFairy       = 1
        self.ProgressiveDustyTrailsFairy           = 1
        self.ProgressiveStarParkFairy              = 1
        self.ProgressiveSpaceAgeSpeedwayFairy      = 1
        self.ProgressiveBeetleBurrowsFairy         = 1
        self.ProgressiveGrendorsLairFairy          = 1
        
        
        self.data_package_ready = asyncio.Event() #A boolean that'll force an await from another function.
        
        self.check_still_connected = 1 #Used to tell the player when Client reconnects to Lua after Lua doesn't send heartbeats.

    async def send_lua_object(self, obj): #I do this a lot so it gets its own function now.
        if self.lua_writer is None: #If there's nothing to tell Lua, skip.
            return
        self.lua_writer.write(json.dumps(obj).encode() + b"\n") #Write Lua our letter.
        await self.lua_writer.drain() #Send it off. There it goes!

    def get_lua_script(self): #The script is inside the APWorld zip so we gotta pull it out lol.
        destination = os.path.join(tempfile.gettempdir(), "SSoI_connector_bizhawk.lua") #Here's where we're gonna put it once we pull it.
        lua_resource = (
            importlib.resources.files(__package__) #Here's the APWorld root.
            .joinpath("hooks") #Lua's in this folder.
            .joinpath("SSoI_connector_bizhawk.lua") #Oh hey there it is!
        )

        with lua_resource.open("rb") as source, open(destination, "wb") as target: #Just wanted to try a fancy way to plug in some variables. I forget if it works the normal way or not.
            shutil.copyfileobj(source, target) #Pull Lua out of the APWorld zip and move it to the destination.

        return destination #Tell the caller where we put it.

    def get_emuhawk_path(self): #Where's the emulator? I need to know so I can open the emulator. No emulator, no play-play video gamey.
        storage = Utils.persistent_load() #Maybe we've saved the location already?
        if "SSoI" in storage: #Double-check storage exists at all. If so...
            path = storage["SSoI"].get("emuhawk_path") #...Pull the last path to the emulator they provided. Surely people move/delete their old versions when upgrading to new versions, right? Hahaha...RIGHT?
            if path and os.path.exists(path): #If the path is stored, and the file it points to exists...
                return path #...Use that, then.

        #Well, if we made it here, then the path was invalid, or didn't exist.
        path = Utils.open_filename("Select EmuHawk.exe PLEASE PLEASE PLEASE SELECT IT NOWWWWW", filetypes=[("EmuHawk", "*.exe")]) #Select the emulator.
        
        if not path: 
            raise RuntimeError("EmuHawk executable not selected.") #SELECT. THE. EMULATOR.

        Utils.persistent_store("SSoI", "emuhawk_path", path) #Thank you. Store the emulator path so the player doesn't have to re-select it every time they wanna play.
        return path #...And use that.

    def get_patched_rom_path(self, opened_thru_patchfile: int): #Same exact thing as get_emuhawk_path, but for your vanilla dump of the vanilla game. Except I don't need to check if the storage exists here, cuz get_emuhawk_path gets called before this.
        
        if opened_thru_patchfile == 0: #But I do need to know if a patchfile wasn't used, because otherwise, Client will open everything and assume the last patched rom should be used again, despite the actual multiworld being played.
            Utils.persistent_store("SSoI", "patched_rom_path", None) #Clear it. I don't know if they're going to be connecting to the same multiworld as their savedata or not.
        
        storage = Utils.persistent_load() #Storage.
        path = storage.get("SSoI", {}).get("patched_rom_path") #Dump path.
        if path and os.path.exists(path): #Path is stored and file still there?
            return path #Use it.

        #Well, if we made it here, then the path was invalid, or didn't exist.                                              
        path = Utils.open_filename("Select Patched Spyro Season of Ice (GBA) ROM. Don't have one yet? Use Open Patch instead of the game's client.", filetypes=[("GBA Files", "*.gba"), ("All files", "*.*")]) #Select your dump.
        if not path:
            raise RuntimeError("ROM not selected.") #Fine, don't. Whatever.

        Utils.persistent_store("SSoI", "patched_rom_path", path) #Save the selected location so the player doesn't have to select it every time they wanna play the APWorld.
        return path #...And use that.

    def launch_bizhawk(self, opened_thru_patchfile: int): #Called by main once main has everything prepped. Opens BizHawk, and the Lua.
        logger.info("Please select EmuHawk.exe") #Debugger logging.
        emuhawk_path = self.get_emuhawk_path() #Get the emulator path.

        logger.info("Please select your Spyro Season of Ice (GBA) ROM.")
        rom_path = self.get_patched_rom_path(opened_thru_patchfile) #Get your patched dump's path.
        lua_script = self.get_lua_script() #Get Lua's path.

        logger.info(f"Launching {rom_path}")
        subprocess.Popen([emuhawk_path, rom_path, "--lua", lua_script]) #Use all the paths, together with the --lua argument, to open everything the player needs at once.

    def lua_location_name_to_id(self): #I do this enough to warrant a function.
        return {name: location_id for location_id, name in self.location_names[self.game].items()} #Invert the superclass's location_id_to_name into a location_name_to_id.

    async def connect_lua(self): #Connect Client to Lua.
        #logger.info("Waiting for BizHawk Lua server...")                                                         
        for _ in range(60): #Every second for the next 60 seconds...
            try:
                self.lua_reader, self.lua_writer = await asyncio.open_connection("127.0.0.1", 43055) #Probe the port that Lua emits from. Lua, my dear, are you there?
                logger.info("Connected to BizHawk.") #Debugger output.
                return #And break.
            except ConnectionRefusedError:
                await asyncio.sleep(1) #Wait a second.

        raise RuntimeError("Timed out waiting for BizHawk Lua server.") #We waited 60 seconds...no Lua. Heartbreaking...

    async def lua_handshake(self): #Rise and shine, script!
        self.lua_writer.write(b"VERSION\n") #Writing on a postcard: "What version are you?"
        await self.lua_writer.drain() #Mailing it out and waiting at the mailbox for a reply.

        response = await self.lua_reader.readline() #I GOT A LETTER OH MY GOSH OH MY GOSH
        if not response:
            raise RuntimeError("BizHawk closed connection during handshake.") #But it was only just a dream...

        version = response.decode().strip() #The letter just has a bunch of numbers in it what is this junk?? zzzzzzzzzzzz
        
        #print(f"WWNES Lua version: {version}") #Nobody needs that psh
 
    '''Not implemented Lua-side yet. Not really on my priority list. Fancy way of saying I tried and got tired of testing it too quickly. I'll implement this if somebody shoots me a working solution for both client and lua side.
    Otherwise, the player will just have to close everything and re-open the patchfile if their client disconnects from the lua.
    
        async def reconnect_lua(self):
        if self.lua_writer:
            try:
                self.lua_writer.close()
                await self.lua_writer.wait_closed()
            except Exception:
                pass

        self.lua_reader = None
        self.lua_writer = None

        logger.error("Waiting for BizHawk...")

        await self.connect_lua()
        await self.lua_handshake()

        logger.error("Lua reconnected.")
    '''    
    
    async def lua_to_ap(self): #How to Talk to the APServer: A Memoir.
        while True: #Keep talkin' buddy.
            try:                                                
                line = await asyncio.wait_for(self.lua_reader.readline(), timeout = 5) #Get a goodiebag from Lua every 5 seconds.                                                    
                if not line: #Absolutely flip out if we don't get a goodiebag.
                    
                    #Actually I think we never reach inside this cuz the reached timeout throws the TimeoutError, so it always defaults to the except & never disconnects from a stalling Lua server as long as it still exists.
                    
                    logger.error("BizHawk disconnected. Please re-launch the patchfile to reconnect.")
                    if self.lua_writer: #Close everything ahead of time. Show's over. Go home.
                        try:
                            self.lua_writer.close()
                            await self.lua_writer.wait_closed()
                        except Exception:
                            pass
                    self.lua_reader = None
                    self.lua_writer = None
                    await self.connect_lua()
                    #await self.reconnect_lua()
                    continue
                else:
                    if self.check_still_connected == 0:
                        self.check_still_connected = 1
                        logger.error("K I see it now. Good to keep goin'.")
                        continue
            except asyncio.TimeoutError: #I'm eat banan. Om Om Om Om Nom.
                self.check_still_connected = 0
                logger.error("Hey. Lua stalled. I don't see it anymore. Is the script still running?") 
                continue
                
            decoded = line.decode().strip() #Ooo what's in our goodiebag? 
            if decoded in ("", "1", "[]"): #Empty...?
                continue #...Sometimes it's nothing and that's okay.

            data = json.loads(decoded) #NOT EMPTY NOT EMPTY AAAUUAUHGHGGHGH so good.
            location_name_to_id = self.lua_location_name_to_id() #Run that cool function I wrote. Actually I think the Superclass has one of these after all. Oh well.
            location_ids = [] #Instantiate a PHAT array.

            for item in data: #For every location Lua wants to send to the APServer...
                #Goal handling.
                if item.get("type") == "VICTORY": #Is it the winner?
                    await self.send_msgs([{"cmd": "StatusUpdate", "status": ClientStatus.CLIENT_GOAL}]) #Tell the APServer that we won!!
                    continue
                #Location handling.                                   
                if item.get("type") in location_name_to_id: #Which location is it, man?
                    location_ids.append(location_name_to_id[item["type"]]) #...Ah, it's this one. Convert it to an ID so the APServer will recognize it for what it truly is.
                    
            if location_ids: #If we got locations to send to the APServer...
                await self.check_locations(location_ids) #...Send'em. Use the Superclass's function to do it.

    #You still good homie? k good.                                  
    async def heartbeat(self): #Client's heartbeat. Tells Lua we're okay.
        while True: #Needs a task to run over and over.
            await asyncio.sleep(3) #Every 3 seconds.
            if not self.lua_writer: #If we haven't made the listener yet, don't try the next part yet.
                continue
            try:
                self.lua_writer.write(json.dumps([{"type": "PING"}]).encode() + b"\n") #Lub dub. Lub dub. Lub dub.
                await self.lua_writer.drain() #Send it to Lua.
            except Exception:
                logger.error("Lua disconnected. Please re-launch the patchfile to reconnect.") #Couldn't send it to Lua. AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                #Actually I'm not sure it ever reaches here but it doesn't hurt to have extensive error handling.



    #ap_to_lua, broken up into async functions where necessary. Superclass's implementation of on_package is nothing. But we need it.
    def on_package(self, cmd: str, args: dict): #Here's the complex stuff. This is all game-specific logic, so it's the meat that'll change between implementations. I really should try to push it all to the Lua.
        if cmd == "Connected": #APServer sends the Connected command the first time Client connects to it.
            
            #Variable upkeep. In case we disconnect then reconnect from/to the APServer without closing Client.
            self.ProgressiveAutumnFairyHomeFairy       = 1
            self.ProgressiveMarketMesaFairy            = 1
            self.ProgressiveLavaPrairieFairy           = 1
            self.ProgressiveMermaidCoastFairy          = 1
            self.ProgressiveStoneAgeSpeedwayFairy      = 1
            self.ProgressiveAntFarmFairy               = 1
            self.ProgressiveWinterFairyHomeFairy       = 1
            self.ProgressiveHummingbirdFortFairy       = 1
            self.ProgressivePandaGardensFairy          = 1
            self.ProgressiveHoneyMarshFairy            = 1
            self.ProgressiveIceAgeSpeedwayFairy        = 1
            self.ProgressiveWaspCityFairy              = 1
            self.ProgressiveSpringFairyHomeFairy       = 1
            self.ProgressiveTimeMachineLabFairy        = 1
            self.ProgressiveRomanCityFairy             = 1
            self.ProgressiveTwilightBulbFactoryFairy   = 1
            self.ProgressiveAquaAgeSpeedwayFairy       = 1
            self.ProgressiveCaterpillarGardensFairy    = 1
            self.ProgressiveSummerFairyHomeFairy       = 1
            self.ProgressiveDustyTrailsFairy           = 1
            self.ProgressiveStarParkFairy              = 1
            self.ProgressiveSpaceAgeSpeedwayFairy      = 1
            self.ProgressiveBeetleBurrowsFairy         = 1
            self.ProgressiveGrendorsLairFairy          = 1
            
            self.location_reminder = 0
            asyncio.create_task(self._connected()) #We need an async function that asks the APServer for all the locations we've sent and all the items we've received.
        elif cmd == "DataPackage": #We got a goodie package.
            self.data_package_ready.set() #Superclass's item_name_to_id is set now.
        elif cmd == "ReceivedItems": #APServer sent us an item. Let's open it up!
            #print("ReceivedItems: ", args)                  
            asyncio.create_task(self._received_items(args)) #Pop that sucka open. APServer put our new items into args, so pass those thru to the async function.

    async def _connected(self): #An async function that asks the APServer for all the locations we've sent and all the items we've received.
        await self.send_msgs([{"cmd": "GetDataPackage", "games": [self.game]}]) #Cool! We're connected. Now, gimmie the goodie package.

    async def _received_items(self, args: dict): #The APServer puts our new items into args.
        #Ey we got some items here!...
        if not self.lua_writer: #Don't do anything if disconnected from Lua.
            return
            
        await self.data_package_ready.wait() #Wait for super's item_name_to_id to get set.
        
        new_items = args.get("items", []) #Parse the args so we can play with our items.
        if not new_items:
            #...Or maybe we don't got items here??                                   
            return

        #Game logic below.
        
        #Instantiate triggers that tell us what items we received. No "self." so that they stay local and I don't have to type out all the disengages, cuz they'll garbage collect with each run. :3
        trigger_ProgressiveAutumnFairyHomeFairy       = 0
        trigger_ProgressiveMarketMesaFairy            = 0
        trigger_ProgressiveLavaPrairieFairy           = 0
        trigger_ProgressiveMermaidCoastFairy          = 0
        trigger_ProgressiveStoneAgeSpeedwayFairy      = 0
        trigger_ProgressiveAntFarmFairy               = 0
        trigger_ProgressiveWinterFairyHomeFairy       = 0
        trigger_ProgressiveHummingbirdFortFairy       = 0
        trigger_ProgressivePandaGardensFairy          = 0
        trigger_ProgressiveHoneyMarshFairy            = 0
        trigger_ProgressiveIceAgeSpeedwayFairy        = 0
        trigger_ProgressiveWaspCityFairy              = 0
        trigger_ProgressiveSpringFairyHomeFairy       = 0
        trigger_ProgressiveTimeMachineLabFairy        = 0
        trigger_ProgressiveRomanCityFairy             = 0
        trigger_ProgressiveTwilightBulbFactoryFairy   = 0
        trigger_ProgressiveAquaAgeSpeedwayFairy       = 0
        trigger_ProgressiveCaterpillarGardensFairy    = 0
        trigger_ProgressiveSummerFairyHomeFairy       = 0
        trigger_ProgressiveDustyTrailsFairy           = 0
        trigger_ProgressiveStarParkFairy              = 0
        trigger_ProgressiveSpaceAgeSpeedwayFairy      = 0
        trigger_ProgressiveBeetleBurrowsFairy         = 0
        trigger_ProgressiveGrendorsLairFairy          = 0
        
        

        for item in new_items: #For every item the APServer sent...
            item_id = item[0] #Each is an array, so get the item ID out of the first index.
            item_name = self.item_names.lookup_in_game(item_id) #Use the Superclass's item_id_to_name to identify the item.
            if item_name == "Progressive Autumn Fairy Home Fairy":
                self.ProgressiveAutumnFairyHomeFairy       += 2 #If the item is a progressive Autumn fairy, give the player an Autumn fairy.
                trigger_ProgressiveAutumnFairyHomeFairy       = 1 #We got an Autumn fairy!! SOUND THE ALARM WOOP WOOP WOOP WOOP
            elif item_name == "Progressive Market Mesa Fairy":
                self.ProgressiveMarketMesaFairy            += 2
                trigger_ProgressiveMarketMesaFairy            = 1
            elif item_name == "Progressive Lava Prairie Fairy":
                self.ProgressiveLavaPrairieFairy           += 2
                trigger_ProgressiveLavaPrairieFairy           = 1
            elif item_name == "Progressive Mermaid Coast Fairy":
                self.ProgressiveMermaidCoastFairy          += 2
                trigger_ProgressiveMermaidCoastFairy          = 1
            elif item_name == "Progressive Stone Age Speedway Fairy":
                self.ProgressiveStoneAgeSpeedwayFairy      += 2
                trigger_ProgressiveStoneAgeSpeedwayFairy      = 1 
            elif item_name == "Progressive Ant Farm Fairy":
                self.ProgressiveAntFarmFairy               += 2
                trigger_ProgressiveAntFarmFairy               = 1
            elif item_name == "Progressive Winter Fairy Home Fairy":
                self.ProgressiveWinterFairyHomeFairy       += 2
                trigger_ProgressiveWinterFairyHomeFairy       = 1
            elif item_name == "Progressive Hummingbird Fort Fairy":
                self.ProgressiveHummingbirdFortFairy       += 2
                trigger_ProgressiveHummingbirdFortFairy       = 1
            elif item_name == "Progressive Panda Gardens Fairy":
                self.ProgressivePandaGardensFairy          += 2
                trigger_ProgressivePandaGardensFairy          = 1
            elif item_name == "Progressive Honey Marsh Fairy":
                self.ProgressiveHoneyMarshFairy            += 2
                trigger_ProgressiveHoneyMarshFairy            = 1
            elif item_name == "Progressive Ice Age Speedway Fairy":
                self.ProgressiveIceAgeSpeedwayFairy        += 2
                trigger_ProgressiveIceAgeSpeedwayFairy        = 1
            elif item_name == "Progressive Wasp City Fairy":
                self.ProgressiveWaspCityFairy              += 2
                trigger_ProgressiveWaspCityFairy              = 1
            elif item_name == "Progressive Spring Fairy Home Fairy":
                self.ProgressiveSpringFairyHomeFairy       += 2
                trigger_ProgressiveSpringFairyHomeFairy       = 1
            elif item_name == "Progressive Time Machine Lab Fairy":
                self.ProgressiveTimeMachineLabFairy        += 2
                trigger_ProgressiveTimeMachineLabFairy        = 1    
            elif item_name == "Progressive Roman City Fairy":
                self.ProgressiveRomanCityFairy             += 2
                trigger_ProgressiveRomanCityFairy             = 1
            elif item_name == "Progressive Twilight Bulb Factory Fairy":
                self.ProgressiveTwilightBulbFactoryFairy   += 2
                trigger_ProgressiveTwilightBulbFactoryFairy   = 1
            elif item_name == "Progressive Aqua Age Speedway Fairy":
                self.ProgressiveAquaAgeSpeedwayFairy       += 2
                trigger_ProgressiveAquaAgeSpeedwayFairy       = 1
            elif item_name == "Progressive Caterpillar Gardens Fairy":
                self.ProgressiveCaterpillarGardensFairy    += 2
                trigger_ProgressiveCaterpillarGardensFairy    = 1
            elif item_name == "Progressive Summer Fairy Home Fairy":
                self.ProgressiveSummerFairyHomeFairy       += 2
                trigger_ProgressiveSummerFairyHomeFairy       = 1
            elif item_name == "Progressive Dusty Trails Fairy":
                self.ProgressiveDustyTrailsFairy           += 2
                trigger_ProgressiveDustyTrailsFairy           = 1
            elif item_name == "Progressive Star Park Fairy":
                self.ProgressiveStarParkFairy              += 2
                trigger_ProgressiveStarParkFairy              = 1
            elif item_name == "Progressive Space Age Speedway Fairy":
                self.ProgressiveSpaceAgeSpeedwayFairy      += 2
                trigger_ProgressiveSpaceAgeSpeedwayFairy      = 1
            elif item_name == "Progressive Beetle Burrows Fairy":
                self.ProgressiveBeetleBurrowsFairy         += 2
                trigger_ProgressiveBeetleBurrowsFairy         = 1
            elif item_name == "Progressive Grendor's Lair Fairy":
                self.ProgressiveGrendorsLairFairy          += 2
                trigger_ProgressiveGrendorsLairFairy          = 1


        if trigger_ProgressiveAutumnFairyHomeFairy == 1 and self.ProgressiveAutumnFairyHomeFairy > 1: #If we sounded the alarm AND WE DIDN'T LITERALLY JUST START PLAYING THE GAME...
            await self.send_lua_object([ #...Tell Lua about our shiny new item, and how many fairies the player has now.
                {"type": "WRITE", "item_name": "Progressive Autumn Fairy Home Fairy", "value": base64.b64encode(bytes([self.ProgressiveAutumnFairyHomeFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Autumn Fairy Home Fairy!"}
            ])

        if trigger_ProgressiveMarketMesaFairy == 1 and self.ProgressiveMarketMesaFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Market Mesa Fairy", "value": base64.b64encode(bytes([self.ProgressiveMarketMesaFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Market Mesa Fairy!"}
            ])

        if trigger_ProgressiveLavaPrairieFairy == 1 and self.ProgressiveLavaPrairieFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Lava Prairie Fairy", "value": base64.b64encode(bytes([self.ProgressiveLavaPrairieFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Lava Prairie Fairy!"}
            ])

        if trigger_ProgressiveMermaidCoastFairy == 1 and self.ProgressiveMermaidCoastFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Mermaid Coast Fairy", "value": base64.b64encode(bytes([self.ProgressiveMermaidCoastFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Mermaid Coast Fairy!"}
            ])

        if trigger_ProgressiveStoneAgeSpeedwayFairy == 1 and self.ProgressiveStoneAgeSpeedwayFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Stone Age Speedway Fairy", "value": base64.b64encode(bytes([self.ProgressiveStoneAgeSpeedwayFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Stone Age Speedway Fairy!"}
            ])

        if trigger_ProgressiveAntFarmFairy == 1 and self.ProgressiveAntFarmFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Ant Farm Fairy", "value": base64.b64encode(bytes([self.ProgressiveAntFarmFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Ant Farm Fairy!"}
            ])

        if trigger_ProgressiveWinterFairyHomeFairy == 1 and self.ProgressiveWinterFairyHomeFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Winter Fairy Home Fairy", "value": base64.b64encode(bytes([self.ProgressiveWinterFairyHomeFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Winter Fairy Home Fairy!"}
            ])

        if trigger_ProgressiveHummingbirdFortFairy == 1 and self.ProgressiveHummingbirdFortFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Hummingbird Fort Fairy", "value": base64.b64encode(bytes([self.ProgressiveHummingbirdFortFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Hummingbird Fort Fairy!"}
            ])

        if trigger_ProgressivePandaGardensFairy == 1 and self.ProgressivePandaGardensFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Panda Gardens Fairy", "value": base64.b64encode(bytes([self.ProgressivePandaGardensFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Panda Gardens Fairy!"}
            ])

        if trigger_ProgressiveHoneyMarshFairy == 1 and self.ProgressiveHoneyMarshFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Honey Marsh Fairy", "value": base64.b64encode(bytes([self.ProgressiveHoneyMarshFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Honey Marsh Fairy!"}
            ])

        if trigger_ProgressiveIceAgeSpeedwayFairy == 1 and self.ProgressiveIceAgeSpeedwayFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Ice Age Speedway Fairy", "value": base64.b64encode(bytes([self.ProgressiveIceAgeSpeedwayFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Ice Age Speedway Fairy!"}
            ])

        if trigger_ProgressiveWaspCityFairy == 1 and self.ProgressiveWaspCityFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Wasp City Fairy", "value": base64.b64encode(bytes([self.ProgressiveWaspCityFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Wasp City Fairy!"}
            ])

        if trigger_ProgressiveSpringFairyHomeFairy == 1 and self.ProgressiveSpringFairyHomeFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Spring Fairy Home Fairy", "value": base64.b64encode(bytes([self.ProgressiveSpringFairyHomeFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Spring Fairy Home Fairy!"}
            ])

        if trigger_ProgressiveTimeMachineLabFairy == 1 and self.ProgressiveTimeMachineLabFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Time Machine Lab Fairy", "value": base64.b64encode(bytes([self.ProgressiveTimeMachineLabFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Time Machine Lab Fairy!"}
            ])

        if trigger_ProgressiveRomanCityFairy == 1 and self.ProgressiveRomanCityFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Roman City Fairy", "value": base64.b64encode(bytes([self.ProgressiveRomanCityFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Roman City Fairy!"}
            ])

        if trigger_ProgressiveTwilightBulbFactoryFairy == 1 and self.ProgressiveTwilightBulbFactoryFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Twilight Bulb Factory Fairy", "value": base64.b64encode(bytes([self.ProgressiveTwilightBulbFactoryFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Twilight Bulb Factory Fairy!"}
            ])

        if trigger_ProgressiveAquaAgeSpeedwayFairy == 1 and self.ProgressiveAquaAgeSpeedwayFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Aqua Age Speedway Fairy", "value": base64.b64encode(bytes([self.ProgressiveAquaAgeSpeedwayFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Aqua Age Speedway Fairy!"}
            ])

        if trigger_ProgressiveCaterpillarGardensFairy == 1 and self.ProgressiveCaterpillarGardensFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Caterpillar Gardens Fairy", "value": base64.b64encode(bytes([self.ProgressiveCaterpillarGardensFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Caterpillar Gardens Fairy!"}
            ])

        if trigger_ProgressiveSummerFairyHomeFairy == 1 and self.ProgressiveSummerFairyHomeFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Summer Fairy Home Fairy", "value": base64.b64encode(bytes([self.ProgressiveSummerFairyHomeFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Summer Fairy Home Fairy!"}
            ])

        if trigger_ProgressiveDustyTrailsFairy == 1 and self.ProgressiveDustyTrailsFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Dusty Trails Fairy", "value": base64.b64encode(bytes([self.ProgressiveDustyTrailsFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Dusty Trails Fairy!"}
            ])

        if trigger_ProgressiveStarParkFairy == 1 and self.ProgressiveStarParkFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Star Park Fairy", "value": base64.b64encode(bytes([self.ProgressiveStarParkFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Star Park Fairy!"}
            ])

        if trigger_ProgressiveSpaceAgeSpeedwayFairy == 1 and self.ProgressiveSpaceAgeSpeedwayFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Space Age Speedway Fairy", "value": base64.b64encode(bytes([self.ProgressiveSpaceAgeSpeedwayFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Progressive Space Age Speedway Fairy!"}
            ])

        if trigger_ProgressiveBeetleBurrowsFairy == 1 and self.ProgressiveBeetleBurrowsFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Beetle Burrows Fairy", "value": base64.b64encode(bytes([self.ProgressiveBeetleBurrowsFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Beetle Burrows Fairy!"}
            ])

        if trigger_ProgressiveGrendorsLairFairy == 1 and self.ProgressiveGrendorsLairFairy > 1:
            await self.send_lua_object([
                {"type": "WRITE", "item_name": "Progressive Grendor's Lair Fairy", "value": base64.b64encode(bytes([self.ProgressiveGrendorsLairFairy])).decode("utf-8")},
                {"type": "DISPLAY_MESSAGE", "message": "Received Grendor's Lair Fairy!"}
            ])

        if self.location_reminder == 0: #Here's where we remind Lua which locations we've already sent, after Client finds out from the APServer.
            self.location_reminder = 1 #And don't remind Lua again. It'll remember.
            for location_id in self.checked_locations: #Superclass's checked_locations.
                location_name = self.location_names.lookup_in_game(location_id) + "_location" #Append _location to the location name so Lua can tell what we're trying to say.
                await self.send_lua_object([{"type": "WRITE", "item_name": location_name}]) #Send it off.

    async def shutdown(self): #What happens when Client is closed. Needs an override of the Superclass's shutdown due to the listeners. Boring stuff.
        for task in (self.lua_task, self.heartbeat_task):
            if task:
                task.cancel()
        if self.lua_writer:
            try:
                self.lua_writer.close()
                await self.lua_writer.wait_closed()
            except Exception:
                pass
        await super().shutdown() #Make sure Superclass also gets a final word in.

    async def connect(self, address): #Async function so everything doesn't stall while the Superclass is connecting Client to the APServer.
        Utils.persistent_store("SSoI", "last_server", address) #Save whatever the player put in as the port.
        await super().connect(address)

    def make_gui(self): #I wanted my own Client. Crazy, right?
        ui = super().make_gui() #Do it up like one of yours, but
        ui.base_title = "Spyro Season of Ice Archipelago Client" #Put my name on it B)
        return ui #Ship it.
        
    async def server_auth(self, password_requested = False): #Superclass's server_auth doesn't ask for the slot name...
        if password_requested and not self.password:
            await super().server_auth(password_requested)

        await self.get_username() #...Gotta do it ourselves.
        await self.send_connect()


def main(*launch_args): #Most important part. Whole Client runs from here.
    Utils.init_logging("Spyro Season of Ice Archipelago Client") #Tells the Archipelago Launcher what name to give the text file in the Logs folder if Client crashes.

    parser = get_base_parser() #This helps patch the player's dump.
    parser.add_argument( #And it does so by adding an additional option, which the patchfile will supply, to Client's opening sequences.
        "diff_file", #Argument's name.
        default = "",
        type = str,
        nargs = "?", #Any amount of args. Optional.
        help = "I love you like a golden banana, my brother." #Would absolutely peel.
    )

    args = parser.parse_args(launch_args) #Yep, add it in. Just like that.

    async def _main(): #Main main in my main in an estimate.
        opened_thru_patchfile = 0 #Used to tell if the player opened Client via the patchfile/Open Patch (gets set to 1 in _main), or via the Wario's Woods Client (stays as 0).
        
        if args.diff_file: #If we got hit wid dat snazzy option we added...
            _, romfile = Patch.create_rom_file(args.diff_file) #...Patch the player's vanilla dump file using the patchfile.
            Utils.persistent_store("SSoI", "patched_rom_path", romfile) #And store the location of that so I don't have to pass the path through like 5 different function args just to get it to the BizHawk launcher function.
            opened_thru_patchfile = 1 #This only gets hit if the player opened Client via the patchfile. launch_bizhawk() gets affected.

        ctx = SSoIContext(args.connect, args.password) #Instantiate the class as an object.
        ctx.launch_bizhawk(opened_thru_patchfile) #Fire off the launch_bizhawk function. Pass through whether or not Client was opened via patchfile.

        await ctx.connect_lua() #Connect to Lua, and wait for success.
        await ctx.lua_handshake() #Wait for Lua to finish opening its eyes for the first time. Welcome to the world, darling.

        ctx.server_task = asyncio.create_task(server_loop(ctx), name = "ServerLoop") #Superclass's...thing. Alright you got me, I forget what this does and I don't feel like looking it up again. Sorry! 
        if gui_enabled: 
            ctx.run_gui() #This prevents the player from connecting to the APServer before Lua is ready to receive anything from it, basically by just not loading the interface yet.

        ctx.run_cli() #Another Superclass thing that's necessary but I don't remember precisely what it does.
        ctx.lua_task = asyncio.create_task(ctx.lua_to_ap(), name = "LuaToAP") #Kick off listener 1.
        ctx.heartbeat_task = asyncio.create_task(ctx.heartbeat(), name = "Heartbeat") #Kick off listener 2.

        await ctx.exit_event.wait() #Now we sit and watch. Until Client is prompted to close.
        await ctx.shutdown() #Client was prompted to close. Turn off the lights and close the door on your way out. See you next time! <33

    asyncio.run(_main()) #Run _main, now that we've finished defining it.


if __name__ == "__main__": #__init__.py adds the game's name to the archipelago launcher, so when the archipelago launcher is used to open a patchfile, it knows to open Client with it, and Client takes care of everything it's built to do.
    main() #Run main, now that we've finished defining it.
