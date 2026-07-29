-- SCP Armory — système de loadout inspiré de Ready or Not pour Garry's Mod
-- Point d'entrée : charge les fichiers partagés, serveur et client.

if SERVER then
	AddCSLuaFile("scp_armory/sh_config.lua")
	AddCSLuaFile("scp_armory/sh_items.lua")
	AddCSLuaFile("scp_armory/sh_autoload.lua")
	AddCSLuaFile("scp_armory/sh_arc9.lua")
	AddCSLuaFile("scp_armory/cl_webimg.lua")
	AddCSLuaFile("scp_armory/cl_menu.lua")
	AddCSLuaFile("scp_armory/cl_config.lua")

	include("scp_armory/sh_config.lua")
	include("scp_armory/sh_items.lua")
	include("scp_armory/sh_autoload.lua")
	include("scp_armory/sh_arc9.lua")
	include("scp_armory/sv_armory.lua")
else
	include("scp_armory/sh_config.lua")
	include("scp_armory/sh_items.lua")
	include("scp_armory/sh_autoload.lua")
	include("scp_armory/sh_arc9.lua")
	include("scp_armory/cl_webimg.lua")
	include("scp_armory/cl_menu.lua")
	include("scp_armory/cl_config.lua")
end
