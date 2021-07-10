-- //////////////////////////////
-- // by iostream (Tommy Helm) //
-- //      <April 2018>        //
-- //////////////////////////////

-- for debugging or further development
local verbose = false

function text(message)
    if message == nil then
        message = "<nil>"
    end
    reaper.ShowConsoleMsg(message);
end

-- <COPY-PASTED source="github...">
-- Get current key and scale
local cur_wnd = reaper.MIDIEditor_GetActive()
if not cur_wnd then
    reaper.ShowMessageBox( "This script needs an active MIDI editor.", "No MIDI editor found", 0)
    return 0
end
-- </COPY-PASTED>

local scale = "122334556677";

if not string.len(scale) == 12 then
    reaper.ShowMessageBox( "Invalid scale", "Invalid scale.", 0)
    return 0;
end

local key = reaper.MIDIEditor_GetSetting_int(cur_wnd, 'scale_root');
if (not key) then
    reaper.ShowMessageBox( "No key enabled.", "No key found.", 0);
    return 0
end

if verbose then
    text("scale: " .. scale .. ", key: " .. key .. "\n");
end

-- diatonic (1-12) to chromatic notes (0-11) mapping of major scale
local major_notes = {
    -- existing steps 1-7:
    0, 2, 4, 5, 7, 9, 11,
 -- the "exotic" ones:
 -- 8  9  A  B  C  D  E  -- (I at least spotted a D in a scale, TODO make 1-Z available!)
    0, 2, 4, 5, 7, 9, 11,
 -- F
    0
};

local cur_take = reaper.MIDIEditor_GetTake(cur_wnd);

local modus_offset = 0; -- = chromatic offset
local modus_offset_note = reaper.MIDIEditor_GetSetting_int(cur_wnd, 'active_note_row');
if verbose then
    text("active_note_row: " .. modus_offset_note .. "\n");
end

if modus_offset_note > 0 then
    modus_offset = (modus_offset_note % 12) - key;
end

if verbose then
    text("modus_offset_note: " .. modus_offset_note .. "\n");
    text("modus offset: " .. modus_offset .. "\n");
end

-- create new scale which is another mode of scale
if modus_offset ~= 0 then
    -- collect all diatonic steps
    local i;
    local scale_length = string.len(scale);
    local diatonic_step;
    local available_diatonic_steps = {};
    local step_index = 1;
    for i = 1, scale_length do
        diatonic_step = string.sub(scale, i, i);
        if diatonic_step ~= "0" then
            available_diatonic_steps[step_index] = diatonic_step;
            step_index = step_index + 1;
        end
    end

    local shifted_scale = "";
    local j;
    local last_diatonic_step;
    step_index = 1;

    for i = 1, scale_length do
       j = (i + modus_offset - 1) % scale_length + 1;
       diatonic_step = string.sub(scale, j, j);

       if diatonic_step ~= "0" then
           shifted_scale = shifted_scale .. available_diatonic_steps[step_index];
           step_index = step_index + 1;
       else
           shifted_scale = shifted_scale .. "0"
       end

    end
    if verbose then
        text(scale .. "\n");
        text(string.rep('_', modus_offset));
        text(shifted_scale .. "\n");
    end
    scale = shifted_scale;
end

-- @param integer (0-11) note
-- @param integer (1..)  diatonic_step
-- @param array[12] note_names         out parameter
function build_note_name(note, diatonic_step, note_names)
    local major_note = major_notes[diatonic_step];
    local diff = note - major_note;
    local name = diatonic_step;
    if diff > 0 then
        name = string.rep("#", diff) .. name;
    elseif diff < 0  then
        name = string.rep("b", -diff) .. name;
    end
    -- is this the tonica and is the scale shifted?
    if diatonic_step == 1 and modus_offset ~= 0 then
        -- mark tonica which is inside of the scale
        if diff == 0 then
            name = name .. "*";
        elseif note_names then
            -- mark tonica which is outside of the scale
            note_names[((note - diff) % 12) + 1] = "*";
        end
    end

    -- if the note has any accidental
    if math.abs(diff) >= 1 and note_names then
        -- add interval in parenthesis ("[" and "]")
        local diatonic_diff;
        if diff > 0 then diatonic_diff = 1; else diatonic_diff = -1; end
        name = name .. ", " .. build_note_name(note, diatonic_step + diatonic_diff);
    end
    return name;
end

-- build note name table
local note_names = {"","","","","","","","","","","",""};
for note = 0, 11, 1 do
    diatonic_step = string.sub(scale, note + 1, note + 1);
    if diatonic_step ~= "0" then
        diatonic_step_int = tonumber(diatonic_step, 16);
        note_names[note + 1] = build_note_name(note, diatonic_step_int, note_names);
    end
end

local track = reaper.GetMediaItemTake_Track(cur_take);
local track_num = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1


reaper.PreventUIRefresh(1);

-- loop over all track notes and set the names
local index;
for note_num = 0, 127, 1 do
    index = (note_num - key - modus_offset) % 12 + 1;
    reaper.SetTrackMIDINoteName(track_num, note_num, -1, note_names[index])
end

reaper.PreventUIRefresh(-1);

if verbose then
    text("\n");
end
