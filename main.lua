local src_path = love.filesystem.getSource()
local ffi = require("ffi")


SAMPLE_RATE = 44100
BUFFER_SIZE = 1024
BITDEPTH = 16
CHANNELS = 2

USER_BPM = 120 -- BPM: beats per minute
USER_LPB = 4 -- LPB: line per beat
USER_TPL = 6 -- TPL: ticks per line


SV_INIT_FLAG_USER_AUDIO_CALLBACK = 0x2
sv = require("sunvox")


function dbg_audio_buffer()
    io.write("audio_buffer: \n")
    for i = 1, BUFFER_SIZE - 1 do
        io.write(string.format("%0x ", audio_buffer[i]))
        if i % 32 == 0 then
            io.write("\n")
        end
    end
    io.write("\nEND audio_buffer\n")
end

function love.load()
    ret_window = love.window.setMode(800, 600, {resizable = true, centered = true })

    sv_config = ffi.string("buffer="..BUFFER_SIZE.."\0")

    sv_obj = sv.sv_init(sv_config, SAMPLE_RATE, CHANNELS, 0)
    sv_sample_rate = sv.sv_get_sample_rate()

    print("Hello, Sunvox @" .. sv_sample_rate .. "Hz")

    sv_slot = sv.sv_open_slot(0)
    print("Opened slot " .. sv_slot)
    sv.sv_lock_slot(sv_slot)
    print("Locked slot " .. sv_slot)
    ret_sv_load = sv.sv_load(sv_slot, src_path .. "/song01.sunvox")
    print("ret_sv_load " .. ret_sv_load)


    audio_stream = love.audio.newQueueableSource(SAMPLE_RATE, BITDEPTH, CHANNELS, 16)

    sv_cur_ticks = ffi.new("uint32_t")

    sound_data = love.sound.newSoundData(BUFFER_SIZE, SAMPLE_RATE, BITDEPTH, CHANNELS)
    ffi_buffer_ptr = sound_data:getFFIPointer()

    last_sys_time = 0

    playing = false

    user_cur_time = 0
    user_out_time = 0
    user_add_time = 0

    audio_stream_cur_pos = 0

    sv_last_ticks = 0
end

function love.update(dt)

    sv_cur_ticks = sv.sv_get_ticks()
    -- print("sv_cur_ticks " .. string.format("%08u", sv_cur_ticks))
    elasped_ticks = sv_cur_ticks - sv_last_ticks
    sv_last_ticks = sv_cur_ticks

    sv_ticks_per_second = sv.sv_get_ticks_per_second()
    -- print("sv_get_ticks_per_second " .. sv_get_ticks_per_second)
    sv_cur_ln = sv.sv_get_current_line(sv_slot)


    sys_time = os.clock() * 1000000
    -- print("sys_time " .. sys_time)
    elapsed_time = sys_time - last_sys_time
    last_sys_time = sys_time

    user_add_time = 0

    if not playing then
        user_cur_time = user_cur_time
        return
    end

    user_add_time = dt * 1000000
    user_cur_time = user_cur_time + user_add_time
    user_out_time = user_cur_time + elapsed_time



    -- dbg_audio_buffer()
    user_ticks_per_second = (USER_BPM * USER_LPB * USER_TPL) / 60 -- ticks per second in user time space

    user_latency = user_out_time - user_cur_time
    sunvox_latency = ( user_latency * sv_ticks_per_second ) / user_ticks_per_second -- latency in system time space
    latency_frames = ( user_latency * SAMPLE_RATE ) / user_ticks_per_second -- latency in frames


    sv.sv_audio_callback(ffi_buffer_ptr, BUFFER_SIZE, latency_frames, sv_cur_ticks + sunvox_latency)


    local ret_audio_stream_queue = audio_stream:queue(sound_data, sound_data:getSize())
    if not ret_audio_stream_queue then
        print("ret_audio_stream_queue " .. tostring(ret_audio_stream_queue))
        print("queue failed")
    end


    local ret_audio_stream_play = audio_stream:play()
    if not ret_audio_stream_play then
        print("ret_audio_stream_play " .. tostring(ret_audio_stream_play))
        print("play failed")
    end

    audio_stream_cur_pos = audio_stream:tell("samples")

    -- print("audio_stream_cur_pos " .. audio_stream_cur_pos)


end

function love.draw()


    love.graphics.print(
    "sv_: " ..
    "\n\tsv_ticks_per_second " .. sv_ticks_per_second ..
    "\n\tsv_cur_ticks " .. sv_cur_ticks ..
    "\n\tsv_last_ticks " .. sv_last_ticks ..
    "\n\telasped_ticks " .. elasped_ticks ..
    "\n\tsv_cur_line " .. sv_cur_ln ..
    "\n time: " ..
    "\n\t sys_time " .. sys_time ..
    "\n\t last_sys_time " .. last_sys_time ..
    "\n\t elapsed_time " .. elapsed_time ..
    "\n\t user_cur_time " .. user_cur_time ..
    "\n\t user_out_time " .. user_out_time ..
    "\n\t user_add_time " .. user_add_time ..
    "\n audio_stream: \n" ..
    "\t audio_stream_cur_pos " .. audio_stream_cur_pos ..
    "\n playing " .. tostring(playing)
    , 100, 40)

    sv_log = sv.sv_get_log(1024)
    love.graphics.print("Log: \n" .. tostring(ffi.string(sv_log)), 100, 300)
end

function love.quit()
    sv.sv_unlock_slot(sv_slot)
    sv.sv_deinit()
end

function love.keypressed(k)
    if k == "r" then
        love.event.quit("restart")
    elseif k == "escape" then
        love.event.quit()
    elseif k == "space" then
        print("play")
        playing = not playing
        sv.sv_play(0)
    end
end
