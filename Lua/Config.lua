local BibaTable = {
    ["RIBAbunkcabinet1"] = "BIBAbunkcabinet",
    ["RIBAbunkcabinet2"] = "BIBAbunkcabinet",

    ["RIBAControlMonitor"] = "BIBAControlMonitor",
    ["RIBABuyableControlMonitor"] = "BIBAControlMonitor",

    ["RIBAControlCamera"] = "BIBAControlCamera",
    ["RIBABuyableControlCamera"] = "BIBAControlCamera",

    ["RIBAStatusMonitor"] = "BIBAStatusMonitor",
    ["RIBABuyableStatusMonitor"] = "BIBAStatusMonitor",

    ["RIBAJunctionBox"] = "BIBAJunctionBox",
    ["RIBABuyableJunctionBox"] = "BIBAJunctionBox",

    ["RIBALamp"] = "BIBALamp",
    ["RIBABuyableLamp"] = "BIBALamp",

    ["RIBAbattery"] = "BIBAbattery",
    ["RIBABuyablebattery"] = "BIBAbattery",

    ["RIBAchargingdock"] = "BIBAchargingdock",
    ["RIBABuyablechargingdock"] = "BIBAchargingdock",

    ["RIBAbigpump"] = "BIBAbigpump",
    ["RIBABuyablebigpump"] = "BIBAbigpump",

    ["RIBAsmallpump"] = "BIBAsmallpump",
    ["RIBABuyablesmallpump"] = "BIBAsmallpump",

    ["RIBAfabricator"] = "BIBAfabricator",
    ["RIBABuyablefabricator"] = "BIBAfabricator",

    ["RIBAdeconstructor"] = "BIBAdeconstructor",
    ["RIBABuyabledeconstructor"] = "BIBAdeconstructor",

    ["RIBAmedfabricator"] = "BIBAmedfabricator",
    ["RIBABuyablemedfabricator"] = "BIBAmedfabricator",

    ["RIBABunk1"] = "BIBAbunk",
    ["RIBABuyableBunk1"] = "BIBAbunk",
    ["RIBABuyableBunk2"] = "BIBAbunk",
    ["RIBABuyableBunk3"] = "BIBAbunk",

    ["RIBAChair1"] = "BIBAChair",
    ["RIBABuyableChair1"] = "BIBAChair",
    ["RIBABuyableChair2"] = "BIBAChair",
    ["RIBABuyableChair3"] = "BIBAChair",

    ["RIBAMedCurtain"] = "BIBAMedCurtain",
    ["RIBABuyableMedCurtain"] = "BIBAMedCurtain",

    ["RIBAcrateshelf2"] = "BIBAcrateshelf_4slots",
    ["RIBABuyablecrateshelf"] = "BIBAcrateshelf_4slots",
    ["RIBABuyablecrateshelf2"] = "BIBAcrateshelf_4slots",
    ["RIBAcrateshelf"] = "BIBAcrateshelf_4slots",

    ["RIBAcrateshelf3"] = "BIBAcrateshelf_1slot",

    ["RIBAsuppliescabinet"] = "BIBAsuppliescabinet",
    ["RIBABuyablesuppliescabinet"] = "BIBAsuppliescabinet",

    ["RIBAmediumsteelcabinet"] = "BIBAmediumsteelcabinet",
    ["RIBABuyablemediumsteelcabinet"] = "BIBAmediumsteelcabinet",
    ["RIBAmediumwindowedsteelcabinet"] = "BIBAmediumsteelcabinet",
    ["RIBABuyablemediumwindowedsteelcabinet"] = "BIBAmediumsteelcabinet",

    ["RIBAsteelcabinet"] = "BIBAsteelcabinet",
    ["RIBABuyablesteelcabinet"] = "BIBAsteelcabinet",
    ["RIBAbigsteelcabinet"] = "BIBAsteelcabinet",
    ["RIBAmedcabinet"] = "BIBAsteelcabinet",
    ["RIBABuyablemedcabinet"] = "BIBAsteelcabinet",

    ["RIBAdivingsuitlocker"] = "BIBAdivingsuitlocker",
    ["RIBABuyabledivingsuitlocker"] = "BIBAdivingsuitlocker",

    ["RIBArailgunshellrack"] = "BIBArailgunshellrack",
    ["RIBABuyablerailgunshellrack"] = "BIBArailgunshellrack",

    ["RIBAcoilgunammoshelf"] = "BIBAcoilgunammoshelf",
    ["RIBABuyablecoilgunammoshelf"] = "BIBAcoilgunammoshelf",

    ["RIBAtoxcabinet"] = "BIBAtoxcabinet",
    ["RIBABuyabletoxcabinet"] = "BIBAtoxcabinet",

    ["RIBAoxygentankshelf"] = "BIBAoxygentankshelf",
    ["RIBABuyableoxygentankshelf"] = "BIBAoxygentankshelf",

    ["RIBAweaponholder"] = "BIBAweaponholder",
    ["RIBABuyableweaponholder"] = "BIBAweaponholder",

    ["RIBAextinguisherbracket"] = "BIBAextinguisherbracket",
    ["RIBABuyableextinguisherbracket"] = "BIBAextinguisherbracket",

    ["RIBAsecuresteelcabinet"] = "BIBAsecuresteelcabinet",
    ["RIBABuyablesecuresteelcabinet"] = "BIBAsecuresteelcabinet"
}

function GetBibaName(name)
    local biba = BibaTable[name]
    if biba == nil then
        -- print("bibanilbibanilbibanilbibanilbibanil")
        return nil
    end
    return biba
end