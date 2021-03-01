--[[
Ultrascene version 1.10
using Lokasenna UI kit version 2 as version 3 documentation was incomplete
--]]


-- User Variables --
listen_freq = .05-- .05 IS DEFUALT in seconds, this is the speed at which lisners are triggered on
scene_limit = 20 -- scene limiter inside ultrascene
-- midi scene limit is currently 95
-- Snapshot limit default is 14, to increate this limit go to /user/AppData/Roaming/REAPER/S&M.ini
-- edit SWSSNAPSHOT_GET and SWSSNAPSHOT_SAVE to increase the limit
-- Screensets at this time have a hard limit of 10

data_file_name = "data.txt"

-- can be gotten by going to actions/showActionMenu/ right click, and copy selected action ID
stop_rec_id = 40044

start_rec_id = 1013

-- End User Variables --

-- Boilerplate UI Code --
local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please install 'Lokasenna's GUI library v2 for Lua', available on ReaPack, then run the 'Set Lokasenna_GUI v2 library path.lua' script in your Action List.", "Whoops!", 0)
    return
end
loadfile(lib_path .. "Core.lua")()

-- Importing the classes used
GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Listbox.lua")()
GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - Options.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end

GUI.name = "Ultrascene"
GUI.x, GUI.y, GUI.w, GUI.h = 1300, 0, 445, 310
--End Lokas

--Ensuring everything is settup for saving data to file
    function get_script_path()
      local info = debug.getinfo(1,'S');
      local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
      return script_path
    end
    
    local script_path = get_script_path()
    data_path = script_path .. data_file_name
    
    --This is what stores the persitant data
    dofile(get_script_path() .. "persistantDataHelper.lua")
    
    if not reaper.file_exists(data_path) then
      local file = io.open(data_path, "w")
      local start_table = {}
      io.close(file)
      table.save(start_table, data_path)
    end

-- Load scenes Info
scenes = table.load(data_path)

-- lists channel names for ui
    function list_scene_names()
    scene_names = {}
    number_of_scenes = 0

    for i=1,scene_limit
    do 
      scene_names[i] = ""
      if (scenes[i] ~= nil) then
        if (i <= 10 - 1) then scene_names[i] = "0" .. i .. " " .. scenes[i].name end
        if (i > 10 - 1) then scene_names[i] = i .. " " .. scenes[i].name end
        number_of_scenes = number_of_scenes + 1
      else
        if (i <= 10 - 1) then scene_names[i] = "0" .. i end
        if (i > 10 - 1) then scene_names[i] = i end
      end
    end
    return number_of_scenes
    end
    
--move the selected scenes around
  function move_scene(start, finish)
    if (finish > 0 and finish <= scene_limit) then
      local old = nil
      if (scenes[finish] ~= nil) then old = scenes[finish] end
      scenes[finish] = scenes[start]
      scenes[start] = old
      
      table.save(scenes, data_path)
      list_scene_names()
      update()
      set_index(finish)
    end
  end
  
  function move_scene_up()
    current = get_index()
    move_scene(current, current - 1)
  end
  
  function move_scene_down()
    current = get_index()
    move_scene(current, current + 1)
  end
  
--adds new scene to list
    function add_scene()
      res, new_scene_name = reaper.GetUserInputs("Add Scene", 1, "Scene Name: ", "", 0);
        
      if (string.len(new_scene_name) > 0) then
        local index = list_scene_names() + 1 --only 
        if (index <= scene_limit) then
          table.insert(scenes, {
            ["index"] = index, -- this needs to be updated
            ["start_rec_enabled"] = false,
            ["stop_rec_enabled"] = false,
            ["screenset_enabled"] = true, 
            ["snapshot_enabled"] = true, 
            ["midi_enabled"] = true,
            ["midi_val"] = index,
            ["screenset_val"] = index,
            ["snapshot_val"] = index,
            ["name"] = new_scene_name,
            })
    
          table.save(scenes, data_path)
          list_scene_names()
          update() -- this is NOT the right way to do this havn't found out how to successfully use GUI.elms.Scenes:update() yet
          set_index(index)
        end
      end
    end
    
-- delete currently selected scene
  function delete_scene()
    local i = get_index()
    
    if (scenes[i] ~= nil) then
      scenes[i] = nil
      table.save(scenes, data_path)
      local n = list_scene_names()
      update() -- this is NOT the right way to do this havn't found out how to successfully use GUI.elms.Scenes:update() yet
      
      if (i==1 and n > 1) then 
        set_index(1)
      end 
      if (i > 1) then 
        set_index(i-1)
      end 
    end
  end
  
  function set_index(val)
    GUI.Val("Scenes", {[val] = true})
    show_settings(val)
  end
  
  function get_index()
    return GUI.Val("Scenes")
  end
  
  --move index up
  function move_down()
    local i = get_index()
    if (i < #scene_names) then
      set_index(i + 1)
    end
  end
  
  --move index down
  function move_up()
    local i = get_index()
    if (i > 1) then
      set_index(i - 1)
    end
  end
  
  --update the listbox ui
  function update_listbox()
  -- this needs to be fixed currently eating memory
  end
  
--master recall sequence
  function master_recall()
    local index = get_index()
    --if(index ~= nil and index > 0) then
      local t = {}
      t.name = GUI.Val("scene_name")
      t.screenset_val = tonumber(GUI.Val("screenset_val"))
      t.snapshot_val = tonumber(GUI.Val("snapshot_val"))
      t.midi_val = tonumber(GUI.Val("midi_val"))
      
      local options = GUI.Val("Options")
      
      t.stop_rec_enabled = options[1]
      t.start_rec_enabled = options[2]
      t.snapshot_enabled = options[3]
      t.screenset_enabled = options[4]
      t.midi_enabled = options[5]
      
      --end recording
      if (t.stop_rec_enabled) then
        stop_rec() 
      end
      
      --midi scene
      if (t.midi_enabled and t.midi_val > 0 and t.midi_val ~= nil) then
        recall_sq(t.midi_val)
      end
      
      --snapshot
      if (t.snapshot_enabled and t.snapshot_val > 0) then
        recall_snapshot(t.snapshot_val)
      end
      
      --screenset
      if (t.screenset_enabled and t.screenset_val > 0) then
      
        recall_screenset(t.screenset_val)
      end
      
      --start recording
      if (t.start_rec_enabled) then
        start_rec()
      end
    --end
  end
    --Stephan Paul Code
    
--recall snapshot
    function recall_snapshot(value)
      local snapshot_command = '_SWSSNAPSHOT_GET'
      
        local snapshot_command = snapshot_command .. tostring(value);
        -- Translate the named command to an ID
        local snapshot_commandID = reaper.NamedCommandLookup(snapshot_command);
        reaper.Main_OnCommand(snapshot_commandID, 0)
    end
    
--save snapshot
    function save_snapshot(value)
      local snapshot_command = '_SWSSNAPSHOT_SAVE'
        local snapshot_command = snapshot_command .. tostring(value);
        -- Translate the named command to an ID
        local snapshot_commandID = reaper.NamedCommandLookup(snapshot_command);
        reaper.Main_OnCommand(snapshot_commandID, 0)
    end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

--recall screenset
    function recall_screenset(value)
      base_val = 40444;
      increment_val = 1;
      if (value ~= 1) then -- check to see if the entered value is not 1 then do the some added logic
        -- Check to see if the value is less than the Command ID of 40453
        -- which is the max value of the last screen shot
        if((base_val + (value - 1)) <= 40453) then
          -- Set the id increment based on the value entered
          base_val = base_val + (value - 1)
        end
      end
      reaper.Main_OnCommand(base_val, 0)
    end
    -- End Stephan Paul Code

--save screenset
    function save_screenset(value)
      base_val = 40464;
      increment_val = 1;
      if (value ~= 1) then -- check to see if the entered value is not 1 then do the some added logic
        -- Check to see if the value is less than the Command ID of 40453
        -- which is the max value of the last screen shot
        if((base_val + (value - 1)) <= 40473) then
          -- Set the id increment based on the value entered
          base_val = base_val + (value - 1)
        end
      end
      reaper.Main_OnCommand(base_val, 0)
    end

-- recall scene on sq6
  function recall_sq(value)
    scene_number = value -- starting at 1
    reaper.StuffMIDIMessage( 
      0, -- 0 for vitual midi keyboard
      '0xC0', -- 0xC0 for channel change, 0xB0 for bank change
      '0x'..string.format("%x", scene_number - 1) , -- scenes 0x00, 0x01...
      0);
  end
  
-- stop recording 
  function stop_rec()
    reaper.Main_OnCommand(stop_rec_id, 0)
  end
  
-- start recording
  function start_rec()
    reaper.Main_OnCommand(start_rec_id, 0)
  end
  
-- save side settings on "save config"
  function save_settings()
    local val = get_index()
    
    if (GUI.Val("scene_name") ~= "") then
      if (scenes[val] == nil) then scenes[val] = {} end
      
      -- Could do both of these as a dictionary and then loop through, this seemed easier to debug tho
      scenes[val].name = GUI.Val("scene_name")
      scenes[val].screenset_val = tonumber(GUI.Val("screenset_val"))
      scenes[val].snapshot_val = tonumber(GUI.Val("snapshot_val"))
      scenes[val].midi_val = tonumber(GUI.Val("midi_val"))
      scenes[val].index = tonumber(GUI.Val("index"))
      
      local options = GUI.Val("Options")
      
      scenes[val].stop_rec_enabled = options[1]
      scenes[val].start_rec_enabled = options[2]
      scenes[val].snapshot_enabled = options[3]
      scenes[val].screenset_enabled = options[4]
      scenes[val].midi_enabled = options[5]
      
      table.save(scenes, data_path)
      list_scene_names()
      update()
      set_index(val)
    end
  end
  
-- populate side settings 
  function show_settings(val)
    if (scenes[val] ~= nil) then
      local t = scenes[val]
  
      GUI.Val("scene_name", t.name)
      GUI.Val("screenset_val", tostring(t.screenset_val))
      GUI.Val("snapshot_val", tostring(t.snapshot_val))
      GUI.Val("midi_val", tostring(t.midi_val))
      GUI.Val("index", tostring(t.index))
      
      --Options Table
      local stop_rec = t.stop_rec_enabled
      local start_rec = t.start_rec_enabled
      local screenset = t.screenset_enabled
      local snapshot = t.snapshot_enabled
      local midi = t.midi_enabled
      GUI.Val("Options", {stop_rec, start_rec, snapshot, screenset, midi})
    
    else
      GUI.Val("scene_name", "")
      GUI.Val("screenset_val", val)
      GUI.Val("snapshot_val", val)
      GUI.Val("midi_val", val)
      GUI.Val("Options", {false, false, false, false, false})
    end
  end

-- store scene/snapshot/etc
  function master_store()
    local index = get_index()
      if(index ~= nil and index > 0) then
         
         local current = scenes[index]
    
         --midi scene
         if (current.midi_enabled and current.midi_val > 0 and current.midi_val ~= nil) then
           --store_sq(current.midi_val)
         end
         
         --snapshot
         if (current.snapshot_enabled and current.snapshot_val > 0) then
           save_snapshot(current.snapshot_val)
         end
         
         --screenset
         if (current.screenset_enabled and current.screenset_val > 0) then
           save_screenset(current.screenset_val)
         end
    end
  end
  
-- trigger listener --information is sent between scripts using reaper.set/getextstate
  function trigger_listner(val, callback)
    if (val ~= nil) then
      if (reaper.GetExtState("ultrascene", tostring(val)) == "true") then
        reaper.SetExtState("ultrascene", tostring(val), "false", true)
        callback()
      end
    end
  end
-------------------------------------


--This should only run once, when script is loaded
function GUI.init()
  GUI.freq = listen_freq --frequency of GUI.func update
  GUI.Val("Scenes", 1) -- sets an intially selected scene
  previous_scene = 1 -- used only to compare when a new scene has been selected, do not use for any other function
  wait_cycles = 0 -- this is also a bad bug fix, i'll do it better when I have time
  show_settings(GUI.Val("Scenes")) --shows initial setting
end

function GUI.func() -- I should write a book "how to find the worst way to do everything" - william 
    -- if selected scene is different than previous scene update settings GUI
    local current_index = get_index()
    if (current_index ~= previous_scene) then
        show_settings(current_index)
        previous_scene = current_index
    end
    -------------------------------------------ADD TRIGGERS HERE -------------------------------
    --listerners are currenty using other scripts to change global persistant variables in reaper
    trigger_listner("up", move_up) 
    trigger_listner("down", move_down)
    trigger_listner("store", master_store)
    trigger_listner("recall", master_recall)
    
end

list_scene_names() -- have to list these here before startup so that They'll display correctly on loan

----------------------------------------

GUI.New("Recall", "Button", {
    z = 11,
    x = 16,
    y = 144,
    w = 48,
    h = 24,
    caption = "Recall",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = master_recall
})

GUI.New("screenset_val", "Textbox", {
    z = 1,
    x = 390.0,
    y = 99.0,
    w = 25,
    h = 20,
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("snapshot_val", "Textbox", {
    z = 1,
    x = 390.0,
    y = 75.0,
    w = 25,
    h = 20,
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("midi_val", "Textbox", {
    z = 1,
    x = 390.0,
    y = 122.0,
    w = 25,
    h = 20,
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20,
    focus = true,
})

GUI.New("scene_name", "Textbox", {
    z = 11,
    x = 287.0,
    y = 165.0,
    w = 145,
    h = 20,
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20,
    focus = true,
})

GUI.New("index", "Textbox", {
    z = 11,
    x = 320.0,
    y = 195.0,
    w = 25,
    h = 20,
    caption = "index",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20,
    focus = true,
})

GUI.New("Store", "Button", {
    z = 11,
    x = 16,
    y = 112,
    w = 48,
    h = 24,
    caption = "Store",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = master_store,
})
--[[
GUI.New("New", "Button", {
    z = 11,
    x = 16,
    y = 80,
    w = 48,
    h = 24,
    caption = "New",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = add_scene
})--]]

GUI.New("Options", "Checklist", {
    z = 11,
    x = 288.0,
    y = 10,
    w = 140,
    h = 145,
    caption = "Options",
    optarray = {"Stop Rec. Before", " Start Rec.", " Snapshot", " Screenset", " Midi Scene"},
    dir = "v",
    pad = 4,
    font_a = 2,
    font_b = 3,
    col_txt = "txt",
    col_fill = "elm_fill",
    bg = "wnd_bg",
    frame = true,
    shadow = true,
    swap = nil,
    opt_size = 20
})

GUI.New("Save Config", "Button", {
    z = 1,
    x = 390,
    y = 195,
    w = 40,
    h = 24,
    caption = "Save",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = save_settings
})

GUI.New("Delete", "Button", {
    z = 11,
    x = 16,
    y = 176,
    w = 48,
    h = 24,
    caption = "Delete",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = delete_scene
})

--These buttons are intened to reorder saved scene, don't have time to implement right now

GUI.New("↑", "Button", {
    z = 11,
    x = 16.0,
    y = 240.0,
    w = 20,
    h = 20,
    caption = "↑",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = move_scene_up

})

GUI.New("↓", "Button", {
    z = 11,
    x = 48.0,
    y = 240.0,
    w = 20,
    h = 20,
    caption = "↓",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = move_scene_down

}) 
-- I know this isn't the right way to do this, eventually adding these on top of one another will cause buffer to overflow I think
-- Should be using GUI.elms.Scenes:redraw()

function update()
GUI.New("Scenes", "Listbox", {
    z = 11,
    x = 80,
    y = 5,
    w = 192,
    h = 295,
    list = scene_names,
    multi = false,
    caption = "Scenes",
    font_a = 3,
    font_b = 4,
    color = "txt",
    col_fill = "elm_fill",
    bg = "elm_bg",
    cap_bg = "wnd_bg",
    shadow = true,
    pad = 4
})
end
update()

GUI.Init()
GUI.Main()

GUI.init()--defined above runs on script startup
GUI.func()--defined above runs every refresh cycle, use with care


