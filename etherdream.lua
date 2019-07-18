--[[ 

MIT License

Copyright (c) 2019 Andrew Berry

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

]]--

etherdream_proto = Proto("etherdream","Ether-Dream Laser Protocol")

-- UDP and TCP Dissector Tables
udp_table = DissectorTable.get("udp.port")

-- Globals
dissector_version = "0.1.0"
dissector_date = "2019-07-18"

local BCAST_PORT = 7654
local STREAM_PORT = 7765
 
local hwRev_field          = ProtoField.uint16(   "etherdream.broadcast.hw_version",     "HW Version", base.DEC)
local swRev_field          = ProtoField.uint16(   "etherdream.broadcast.sw_version",     "SW Version",        base.DEC)
local bufferCapacity_field = ProtoField.uint16(   "etherdream.broadcast.buffer_cap",     "Buffer Capacity",        base.DEC)
local maxPointRate_field   = ProtoField.uint16(   "etherdream.broadcast.max_point_rate", "Max Point Rate",     base.DEC)

local dac_protocol_field        = ProtoField.uint8(    "etherdream.dac_status.protocol",        "DAC Protocol",           base.DEC)
local dac_le_state_field        = ProtoField.uint8(    "etherdream.dac_status.le_state",        "DAC Light Engine State", base.DEC)
local dac_playbackstate_field   = ProtoField.uint8(    "etherdream.dac_status.playback_sate",   "DAC Playback State",     base.DEC)
local dac_source_field          = ProtoField.uint8(    "etherdream.dac_status.source",          "DAC Source",             base.DEC)
local dac_le_flags_field        = ProtoField.uint16(   "etherdream.dac_status.le_flags",        "DAC Light Engine Flags", base.DEC)
local dac_playback_flags_field  = ProtoField.uint16(   "etherdream.dac_status.playback_flags",  "DAC Playback Flags",     base.DEC)
local dac_source_flags_field    = ProtoField.uint16(   "etherdream.dac_status.source_flags",    "DAC Source Flags",       base.DEC)
local dac_buffer_fullness_field = ProtoField.uint16(   "etherdream.dac_status.buffer_fullness", "DAC Buffer Fullness",    base.DEC)
local dac_pointrate_field       = ProtoField.uint32(   "etherdream.dac_status.pointrate", 	    "DAC Pointrate",          base.DEC)
local dac_pointcount_field      = ProtoField.uint32(   "etherdream.dac_status.pointcount", 	    "DAC Point Count",        base.DEC)

local command_field				= ProtoField.string( "etherdream.command", "Command", base.ASCII)

local data_nPoints				= ProtoField.uint16( "etherdream.data.npoints", "Num Points", base.DEC)

etherdream_proto.fields = {
    hwRev_field,
	swRev_field,
	bufferCapacity_field,
	maxPointRate_field,
	
	dac_protocol_field,
	dac_le_state_field,      
	dac_playbackstate_field  ,
	dac_source_field         ,
	dac_le_flags_field       ,
	dac_playback_flags_field ,
	dac_source_flags_field   ,
	dac_buffer_fullness_field,
	dac_pointrate_field      ,
	dac_pointcount_field     ,

	command_field,
	
	data_nPoints,
}

function dissect_dacstatus(buffer, pinfo, tree)
    subtree = tree:add(buffer(),"DAC Status")
	subtree:add_le(dac_protocol_field, buffer(0,1))
	subtree:add_le(dac_le_state_field, buffer(1,1))
	subtree:add_le(dac_playbackstate_field, buffer(2,1))
	subtree:add_le(dac_source_field, buffer(3,1))
	subtree:add_le(dac_le_flags_field, buffer(4,2))
	subtree:add_le(dac_playback_flags_field, buffer(6,2))
	subtree:add_le(dac_source_flags_field, buffer(8,2))
	subtree:add_le(dac_buffer_fullness_field, buffer(10,2))
	subtree:add_le(dac_pointrate_field, buffer(12,4))
	subtree:add_le(dac_pointcount_field, buffer(16,4))
end

function dissect_data(buffer, pinfo, tree)
	subtree = tree
	subtree:add_le(data_nPoints, buffer(1,2))
end

function etherdream_proto.dissector(buffer,pinfo,tree)
	pinfo.cols.protocol = "EtherDream"
	
	if(pinfo.dst_port == BCAST_PORT) then
		pinfo.cols.info = "DAC Advertisement"
		local subtree = tree:add(etherdream_proto, buffer(), "EtherDream DAC Advertisement")
		--TODO: Report MAC Address
		subtree:add_le(hwRev_field, buffer(6,2) )
		subtree:add_le(swRev_field, buffer(8,2) )
		subtree:add_le(bufferCapacity_field, buffer(10,2) )
		subtree:add_le(maxPointRate_field, buffer(12,4) )
		dissect_dacstatus(buffer(16, buffer:len()-16), pinfo, subtree)
	
	elseif(pinfo.dst_port == STREAM_PORT) then
		pinfo.cols.info = "Control Data"
		local subtree = tree:add(etherdream_proto, buffer(), "EtherDream Control")
		
		local command = buffer(0,1):string()
		
		if (command == 'p') then
			subtree:append_text(   " (Prepare Stream)")
			pinfo.cols.info:append(" (Prepare Stream)")
		elseif (command == 'b') then
			subtree:append_text(   " (Begin Playback)")
			pinfo.cols.info:append(" (Begin Playback)")
		elseif (command == 'q') then
			subtree:append_text(   " (Queue Rate Change)")
			pinfo.cols.info:append(" (Queue Rate Change)")
		elseif (command == 'd') then
			subtree:append_text(   " (Write Data)")
			pinfo.cols.info:append(" (Write Data)")
			dissect_data(buffer, pinfo, subtree)
		elseif (command == 's') then
			subtree:append_text(   " (Stop)")
			pinfo.cols.info:append(" (Stop)")
		elseif (command == 'c') then
			subtree:append_text(   " (Clear E-Stop)")
			pinfo.cols.info:append(" (Clear E-Stop)")
		elseif (command == '?') then
			subtree:append_text(   " (Ping)")
			pinfo.cols.info:append(" (Ping)")
		end
		
		
	elseif(pinfo.src_port == STREAM_PORT) then
		pinfo.cols.info = "DAC Response"
		local subtree = tree:add(etherdream_proto, buffer(), "EtherDream DAC Response")
		
		local dissect_status = true
		
		local dac_response = buffer(0,1):string()
		
		if(dac_response == 'a') then
			subtree:append_text(" (ACK)")
			pinfo.cols.info:append(" (ACK)")
		elseif(dac_response == 'F') then
			subtree:append_text(" (NAK: Insufficient Buffer Space)")
			pinfo.cols.info:append(" (NAK: Insufficient Buffer Space)"	)		
		elseif(dac_response == 'I') then
			subtree:append_text(" (NAK: Invalid)")
			pinfo.cols.info:append(" (NAK: Invalid)")
		elseif(dac_response == '!') then
			subtree:append_text(" (NAK: Emergency Stop Active)")
			pinfo.cols.info:append(" (NAK: Emergency Stop Active)")
		else 
			subtree:append_text(" DISSECTOR ERROR: Unknown response code!")
			pinfo.cols.info:append(" DISSECTOR ERROR: Unknown response code!")
		end
		
		dissect_dacstatus(buffer(1, buffer:len()-1), pinfo, subtree)
	end
 
 
--[[ 
  --pinfo.cols.protocol = buffer(0,22):string()
  
  -- if the message is less then the length 
  if (buffer:len() < 23) then return end
  
  if (buffer(0,23):string() == "Wysiwyg Laser Protocol\0" ) then
	pinfo.cols.protocol = "WYSIWYG Laser Data"
    local subtree = tree:add(wysiwyg_proto,buffer(),"WYSIWYG Laser Protocol Data")
	
	if (buffer:len() < 44) then
	  pinfo.cols.info = "ERR: message too short"
	  return
	end
	
	version = buffer(23,1):uint()
	
	if (version ~= 1) then
	  pinfo.cols.info = "ERR: " .. version .. " is not a valid version"
	  return
	end
	
	local device = buffer(44,1):uint()+1
	local frame = buffer(45,1):uint()
	local fragment = buffer(46,1):uint()
	
	local header = subtree:add(buffer(0,52), "Header (device " .. device .. ", frame " .. frame .. ", fragment " .. fragment .. ")")
	
	header:add( version_field,      buffer(23,1) )
    header:add( device_field,       buffer(32,1) )
	header:add( frame_field,        buffer(33,1) )
	header:add( fragment_field,     buffer(34,1) )
	header:add( numFragments_field, buffer(35,1) )
	header:add( numPoints_field,    buffer(36,1) )
	
	local pointCount = buffer(36,1):uint()
	
	if (pointCount * 6 + 44 ~= buffer:len()) then
		  pinfo.cols.info = "ERR: Header claims " .. pointCount .. "points. Expected total of " .. pointCount * 6 + 44 .. " bytes but received " .. buffer:len()
	  return
	end
	
	local pointData = subtree:add(buffer(44, buffer:len()-44), "Points (" .. pointCount .. ")")
	
	for i=0, pointCount-1, 1 do
      x = buffer(44 + i * 6 + 0, 1):int()
	  y = buffer(44 + i * 6 + 1, 1):int()
	  -- need to add LSB of x and y positions
	  r = buffer(44 + i * 6 + 3, 1):uint()
	  g = buffer(44 + i * 6 + 4, 1):uint()
	  b = buffer(44 + i * 6 + 5, 1):uint()
	  pointData:add(buffer(44+i*6, 6),  string.format("pt%3d: %6d,%6d: %3d,%3d,%3d", i, x, y, r, g, b))
	end
	
  end

]]--

end -- end function citp_proto.dissector





-- ---------------------------------------------------------------------
-- Formatters
-- ---------------------------------------------------------------------


udp_table = DissectorTable.get("udp.port")
tcp_table = DissectorTable.get("tcp.port")

-- register our protocol to handle udp port 7777
udp_table:add(BCAST_PORT, etherdream_proto)
tcp_table:add(STREAM_PORT, etherdream_proto)
--Debug, Add Mbox
--CITP_add_port(6436) -- PRG Mbox
--CITP_add_port(4011) -- Arkaos Media Master