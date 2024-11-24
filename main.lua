local src_path = love.filesystem.getSource()
local ffi = require("ffi")


SAMPLE_RATE = 44100
BUFFER_SIZE = 1024
BITDEPTH = 16
CHANNELS = 2

SV_INIT_FLAG_USER_AUDIO_CALLBACK = 0x2
sv = require("sv")


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


    -- local sv_init_flag = ffi.new("uint32_t")
    -- sv_init_flag = SV_INIT_FLAG_USER_AUDIO_CALLBACK
    -- print("sv_init_flag " .. sv_init_flag)


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

    framecounter = 0
end

function love.update(dt)

    cur_time = love.timer.getTime()
    elapsed_time = cur_time - last_time
    last_time = cur_time

    time = love.timer.getTime() * 100000
    print("time " .. tostring(ffi.cast("uint32_t",time)))

    sv_cur_ticks = sv.sv_get_ticks()
    -- print("sv_cur_ticks " .. string.format("%08u", sv_cur_ticks))

    sv_get_ticks_per_second = sv.sv_get_ticks_per_second()
    -- print("sv_get_ticks_per_second " .. sv_get_ticks_per_second)

    ffi_buffer_ptr = sound_data:getFFIPointer()

    -- dbg_audio_buffer()
    user_ticks_per_second =

    user_latency = user_out_time - user_cur_time
    sunvox_latency = ( user_latency * sv_get_ticks_per_second() ) / user_ticks_per_second
    sv.sv_audio_callback(ffi_buffer_ptr, BUFFER_SIZE, 32, sv_cur_ticks)

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

    love.graphics.print("framecounter " .. framecounter, 100, 80)

    love.graphics.print("sv_get_ticks_per_second " .. sv_get_ticks_per_second, 100, 40)

    sv_cur_ln = sv.sv_get_current_line(sv_slot)
    love.graphics.print("Current line: " .. sv_cur_ln, 100, 100)

    love.graphics.print("cur_ticks " .. string.format("%08u", sv_cur_ticks), 100, 120)

    love.graphics.print("audio_stream_cur_pos " .. audio_stream_cur_pos, 100, 140)

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
        sv.sv_play(0)
    end
end
