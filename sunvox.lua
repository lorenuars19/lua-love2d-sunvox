local ffi = require("ffi")
ffi.cdef([[


typedef struct
{
    uint8_t	note;           /* NN: 0 - nothing; 1..127 - note num; 128 - note off; 129, 130... - see NOTECMD_* defines */
    uint8_t	vel;            /* VV: Velocity 1..129; 0 - default */
    uint16_t	module;         /* MM: 0 - nothing; 1..65535 - module number + 1 */
    uint16_t	ctl;            /* 0xCCEE: CC: 1..127 - controller number + 1; EE - effect */
    uint16_t	ctl_val;        /* 0xXXYY: controller value or effect parameter */
} sunvox_note;


/*
   Functions
   (use the functions with the label "USE LOCK/UNLOCK" within the sv_lock_slot() / sv_unlock_slot() block only!)
*/

/*
   sv_init(), sv_deinit() - global sound system init/deinit
   Parameters:
     config - string with additional configuration in the following format: "option_name=value|option_name=value";
              example: "buffer=1024|audiodriver=alsa|audiodevice=hw:0,0";
              use NULL for automatic configuration;
     freq - desired sample rate (Hz); min - 44100;
            the actual rate may be different, if SV_INIT_FLAG_USER_AUDIO_CALLBACK is not set;
     channels - only 2 supported now;
     flags - mix of the SV_INIT_FLAG_xxx flags.
*/
int sv_init( const char* config, int freq, int channels, const uint32_t flags );
int sv_deinit( void );

/*
   sv_get_sample_rate() - get current sampling rate (it may differ from the frequency specified in sv_init())
*/
int sv_get_sample_rate( void );

/*
   sv_update_input() -
   handle input ON/OFF requests to enable/disable input ports of the sound card
   (for example, after the Input module creation).
   Call it from the main thread only, where the SunVox sound stream is not locked.
*/
int sv_update_input( void );

/*
   sv_audio_callback() - get the next piece of SunVox audio from the Output module.
   With sv_audio_callback() you can ignore the built-in SunVox sound output mechanism and use some other sound system.
   SV_INIT_FLAG_USER_AUDIO_CALLBACK flag in sv_init() must be set.
   Parameters:
     buf - destination buffer of type int16_t (if SV_INIT_FLAG_AUDIO_INT16 used in sv_init())
           or float (if SV_INIT_FLAG_AUDIO_FLOAT32 used in sv_init());
           stereo data will be interleaved in this buffer: LRLR... (LR is a single frame (Left+Right));
     frames - number of frames in destination buffer;
     latency - audio latency (in frames);
     out_time - buffer output time (in system ticks);
   Return values: 0 - silence, the output buffer is filled with zeros; 1 - the output buffer is filled.
   Example 1 (simplified, without accurate time sync) - suitable for most cases:
     sv_audio_callback( buf, frames, 0, sv_get_ticks() );
   Example 2 (accurate time sync) - when you need to maintain exact time intervals between incoming events (notes, commands, etc.):
     user_out_time = ... ; //output time in user time space (depends on your own implementation)
     user_cur_time = ... ; //current time in user time space
     user_ticks_per_second = ... ; //ticks per second in user time space
     user_latency = user_out_time - user_cur_time; //latency in user time space
     uint32_t sunvox_latency = ( user_latency * sv_get_ticks_per_second() ) / user_ticks_per_second; //latency in system time space
     uint32_t latency_frames = ( user_latency * sample_rate_Hz ) / user_ticks_per_second; //latency in frames
     sv_audio_callback( buf, frames, latency_frames, sv_get_ticks() + sunvox_latency );
*/
int sv_audio_callback( void* buf, int frames, int latency, uint32_t out_time );

/*
   sv_audio_callback2() - send some data to the Input module and receive the filtered data from the Output module.
   It's the same as sv_audio_callback() but you also can specify the input buffer.
   Parameters:
     ...
     in_type - input buffer type: 0 - int16_t (16bit integer); 1 - float (32bit floating point);
     in_channels - number of input channels;
     in_buf - input buffer; stereo data must be interleaved in this buffer: LRLR... ; where the LR is the one frame (Left+Right channels);
*/
int sv_audio_callback2( void* buf, int frames, int latency, uint32_t out_time, int in_type, int in_channels, void* in_buf );

/*
   sv_open_slot(), sv_close_slot(), sv_lock_slot(), sv_unlock_slot() -
   open/close/lock/unlock sound slot for SunVox.
   You can use several slots simultaneously (each slot with its own SunVox engine).
   Use lock/unlock when you simultaneously read and modify SunVox data from different threads (for the same slot);
   example:
     thread 1: sv_lock_slot(0); sv_get_module_flags(0,mod1); sv_unlock_slot(0);
     thread 2: sv_lock_slot(0); sv_remove_module(0,mod2); sv_unlock_slot(0);
   Some functions (marked as "USE LOCK/UNLOCK") can't work without lock/unlock at all.
*/
int sv_open_slot( int slot );
int sv_close_slot( int slot );
int sv_lock_slot( int slot );
int sv_unlock_slot( int slot );

/*
   sv_load(), sv_load_from_memory() -
   load SunVox project from the file or from the memory block.
*/
int sv_load( int slot, const char* name );
int sv_load_from_memory( int slot, void* data, uint32_t data_size );

/*
   sv_save() - save project to the file;
   sv_save_to_memory() - save project to memory; return value: memory block allocated with malloc();
   Parameters:
     slot;
     name - file name;
     size - pointer to a variable in which the size of the data will be stored.
   Example 1:
     sv_save( slot, "proj.sunvox" );
   Example 2:
     size_t data_size = 0; //in bytes
     void* data = sv_save_to_memory( slot, &data_size );
     if( data )
     {
       if( data_size )
       {
         //do something with data
       }
       free( data );
     }
*/
int sv_save( int slot, const char* name );
void* sv_save_to_memory( int slot, size_t* size );

/*
   sv_play() - play from the current position;
   sv_play_from_beginning() - play from the beginning (line 0);
   sv_stop(): first call - stop playing; second call - reset all SunVox activity and switch the engine to standby mode;
   sv_pause() - pause the audio stream on the specified slot;
   sv_resume() - resume the audio stream on the specified slot;
   sv_sync_resume() - wait for sync (pattern effect 0x33 on any slot) and resume the audio stream on the specified slot;
*/
int sv_play( int slot );
int sv_play_from_beginning( int slot );
int sv_stop( int slot );
int sv_pause( int slot );
int sv_resume( int slot );
int sv_sync_resume( int slot );

/*
   sv_set_autostop(), sv_get_autostop() -
   autostop values: 0 - disable autostop; 1 - enable autostop.
   When autostop is OFF, the project plays endlessly in a loop.
*/
int sv_set_autostop( int slot, int autostop );
int sv_get_autostop( int slot );

/*
   sv_end_of_song() return values: 0 - song is playing now; 1 - stopped.
*/
int sv_end_of_song( int slot );

/*
*/
int sv_rewind( int slot, int line_num );

/*
   sv_volume() - set volume from 0 (min) to 256 (max 100%);
   negative values are ignored;
   return value: previous volume;
*/
int sv_volume( int slot, int vol );

/*
   sv_set_event_t() - set the timestamp of events to be sent by sv_send_event()
   Parameters:
     slot;
     set: 1 - set; 0 - reset (use automatic time setting - the default mode);
     t: timestamp (in system ticks).
   Examples:
     sv_set_event_t( slot, 1, 0 ) //not specified - further events will be processed as quickly as possible
     sv_set_event_t( slot, 1, sv_get_ticks() ) //time when the events will be processed = NOW + sound latancy * 2
*/
int sv_set_event_t( int slot, int set, int t );

/*
   sv_send_event() - send an event (note ON, note OFF, controller change, etc.)
   Parameters:
     slot;
     track_num - track number within the pattern;
     note: 0 - nothing; 1..127 - note num; 128 - note off; 129, 130... - see NOTECMD_xxx defines;
     vel: velocity 1..129; 0 - default;
     module: 0 (empty) or module number + 1 (1..65535);
     ctl: 0xCCEE. CC - number of a controller (1..255). EE - effect;
     ctl_val: value of controller or effect.
*/
int sv_send_event( int slot, int track_num, int note, int vel, int module, int ctl, int ctl_val );

/*
*/
int sv_get_current_line( int slot ); /* Get current line number */
int sv_get_current_line2( int slot ); /* Get current line number in fixed point format 27.5 */
int sv_get_current_signal_level( int slot, int channel ); /* From 0 to 255 */

/*
*/
const char* sv_get_song_name( int slot );
int sv_set_song_name( int slot, const char* name );
int sv_get_song_bpm( int slot );
int sv_get_song_tpl( int slot );

/*
   sv_get_song_length_frames(), sv_get_song_length_lines() -
   get the project length.
   Frame is one discrete of the sound. Sample rate 44100 Hz means, that you hear 44100 frames per second.
*/
uint32_t sv_get_song_length_frames( int slot );
uint32_t sv_get_song_length_lines( int slot );

/*
   sv_get_time_map()
   Parameters:
     slot;
     start_line - first line to read (usually 0);
     len - number of lines to read;
     dest - pointer to the buffer (size = len*sizeof(uint32_t)) for storing the map values;
     flags:
       SV_TIME_MAP_SPEED: dest[X] = BPM | ( TPL << 16 ) (speed at the beginning of line X);
       SV_TIME_MAP_FRAMECNT: dest[X] = frame counter at the beginning of line X;
   Return value: 0 if successful, or negative value in case of some error.
*/
int sv_get_time_map( int slot, int start_line, int len, uint32_t* dest, int flags );

/*
   sv_new_module() - create a new module;
   sv_remove_module() - remove selected module;
   sv_connect_module() - connect the source to the destination;
   sv_disconnect_module() - disconnect the source from the destination;
*/
int sv_new_module( int slot, const char* type, const char* name, int x, int y, int z ); /* USE LOCK/UNLOCK! */
int sv_remove_module( int slot, int mod_num ); /* USE LOCK/UNLOCK! */
int sv_connect_module( int slot, int source, int destination ); /* USE LOCK/UNLOCK! */
int sv_disconnect_module( int slot, int source, int destination ); /* USE LOCK/UNLOCK! */

/*
   sv_load_module() - load a module or sample; supported file formats: sunsynth, xi, wav, aiff, ogg, mp3, flac;
                      return value: new module number or negative value in case of some error;
   sv_load_module_from_memory() - load a module or sample from the memory block;
*/
int sv_load_module( int slot, const char* file_name, int x, int y, int z );
int sv_load_module_from_memory( int slot, void* data, uint32_t data_size, int x, int y, int z );

/*
   sv_sampler_load() - load a sample into the Sampler; to replace the whole sampler - set sample_slot to -1;
   sv_sampler_load_from_memory() - load a sample from the memory block;
   sv_sampler_par() - set/get sample parameter:
     0 - Loop begin: 0 ... (sample_length - 1);
     1 - Loop length: 0 ... (sample_length - loop_begin);
     2 - Loop type: 0 - none; 1 - fwd; 2 - bidirectional;
     3 - Loop release flag: 0 - none; 1 - loop will be finished after the note release;
     4 - Volume: 0 ... 64;
     5 - Panning: 0 (left) ... 128 (center) ... 255 (right);
     6 - Finetune: -128 ... 0 ... +127 (higher value = higher pitch);
     7 - Relative note: -128 ... 0 ... +127 (higher value = higher pitch);
     8 - Start position: 0 ... (sample_length - 1);
*/
int sv_sampler_load( int slot, int mod_num, const char* file_name, int sample_slot );
int sv_sampler_load_from_memory( int slot, int mod_num, void* data, uint32_t data_size, int sample_slot );
int sv_sampler_par( int slot, int mod_num, int sample_slot, int par, int par_val, int set );

/*
   sv_metamodule_load() - load a file into the MetaModule; supported file formats: sunvox, mod, xm, midi;
   sv_vorbis_load() - load a file into the Vorbis Player; supported file formats: ogg;
*/
int sv_metamodule_load( int slot, int mod_num, const char* file_name );
int sv_metamodule_load_from_memory( int slot, int mod_num, void* data, uint32_t data_size );
int sv_vplayer_load( int slot, int mod_num, const char* file_name );
int sv_vplayer_load_from_memory( int slot, int mod_num, void* data, uint32_t data_size );

/*
   sv_get_number_of_modules() - get the number of module slots (not the actual number of modules).
   The slot can be empty or it can contain a module.
   Here is the code to determine that the module slot X is not empty: ( sv_get_module_flags( slot, X ) & SV_MODULE_FLAG_EXISTS ) != 0;
*/
int sv_get_number_of_modules( int slot );

/*
   sv_find_module() - find a module by name;
   return value: module number or -1 (if not found);
*/
int sv_find_module( int slot, const char* name );

/*
*/
uint32_t sv_get_module_flags( int slot, int mod_num ); /* SV_MODULE_FLAG_* */

/*
   sv_get_module_inputs(), sv_get_module_outputs() -
   get pointers to the int[] arrays with the input/output links.
   Number of input links = ( module_flags & SV_MODULE_INPUTS_MASK ) >> SV_MODULE_INPUTS_OFF.
   Number of output links = ( module_flags & SV_MODULE_OUTPUTS_MASK ) >> SV_MODULE_OUTPUTS_OFF.
   (this is not the actual number of connections: some links may be empty (value = -1))
*/
int* sv_get_module_inputs( int slot, int mod_num );
int* sv_get_module_outputs( int slot, int mod_num );

/*
*/
const char* sv_get_module_type( int slot, int mod_num );

/*
*/
const char* sv_get_module_name( int slot, int mod_num );
int sv_set_module_name( int slot, int mod_num, const char* name );

/*
   sv_get_module_xy() - get module XY coordinates packed in a single uint32 value:
   ( x & 0xFFFF ) | ( ( y & 0xFFFF ) << 16 )
   Normal working area: 0x0 ... 1024x1024
   Center: 512x512
   Use SV_GET_MODULE_XY() macro to unpack X and Y.
*/
uint32_t sv_get_module_xy( int slot, int mod_num );
int sv_set_module_xy( int slot, int mod_num, int x, int y );

/*
   sv_get_module_color()
   sv_set_module_color()
   get/set module color in the following format: 0xBBGGRR
*/
int sv_get_module_color( int slot, int mod_num );
int sv_set_module_color( int slot, int mod_num, int color );

/*
   sv_get_module_finetune() - get the relative note and finetune of the module;
   return value: ( finetune & 0xFFFF ) | ( ( relative_note & 0xFFFF ) << 16 ).
   Use SV_GET_MODULE_FINETUNE() macro to unpack finetune and relative_note.
*/
uint32_t sv_get_module_finetune( int slot, int mod_num );

/*
   sv_set_module_finetune() - change the finetune immediately;
   sv_set_module_relnote() - change the relative note immediately;
*/
int sv_set_module_finetune( int slot, int mod_num, int finetune );
int sv_set_module_relnote( int slot, int mod_num, int relative_note );

/*
   sv_get_module_scope2() return value = received number of samples (may be less or equal to samples_to_read).
   Example:
     int16_t buf[ 1024 ];
     int received = sv_get_module_scope2( slot, mod_num, 0, buf, 1024 );
     //buf[ 0 ] = value of the first sample (-32768...32767);
     //buf[ 1 ] = value of the second sample;
     //...
     //buf[ received - 1 ] = value of the last received sample;
*/
uint32_t sv_get_module_scope2( int slot, int mod_num, int channel, int16_t* dest_buf, uint32_t samples_to_read );

/*
   sv_module_curve() - access to the curve values of the specified module
   Parameters:
     slot;
     mod_num - module number;
     curve_num - curve number;
     data - destination or source buffer;
     len - number of items to read/write;
     w - read (0) or write (1).
   return value: number of items processed successfully.

   Available curves (Y=CURVE[X]):
     MultiSynth:
       0 - X = note (0..127); Y = velocity (0..1); 128 items;
       1 - X = velocity (0..256); Y = velocity (0..1); 257 items;
       2 - X = note (0..127); Y = pitch (0..1); 128 items;
           pitch range: 0 ... 16384/65535 (note0) ... 49152/65535 (note128) ... 1; semitone = 256/65535;
     WaveShaper:
       0 - X = input (0..255); Y = output (0..1); 256 items;
     MultiCtl:
       0 - X = input (0..256); Y = output (0..1); 257 items;
     Analog Generator, Generator:
       0 - X = drawn waveform sample number (0..31); Y = volume (-1..1); 32 items;
     FMX:
       0 - X = custom waveform sample number (0..255); Y = volume (-1..1); 256 items;
*/
int sv_module_curve( int slot, int mod_num, int curve_num, float* data, int len, int w );

/*
*/
int sv_get_number_of_module_ctls( int slot, int mod_num );
const char* sv_get_module_ctl_name( int slot, int mod_num, int ctl_num );

/*
   sv_get_module_ctl_value() - get the value of the specified module controller
   Parameters:
     slot;
     mod_num - module number;
     ctl_num - controller number (from 0);
     scaled - describes the type of the returned value:
       0 - real value (0,1,2...) as it is stored inside the controller;
           but the value displayed in the program interface may be different - you can use scaled=2 to get the displayed value;
       1 - scaled (0x0000...0x8000) if the controller type = 0, or the real value if the controller type = 1 (enum);
           this value can be used in the pattern column XXYY;
       2 - final value displayed in the program interface -
           in most cases it is identical to the real value (scaled=0), and sometimes it has an additional offset;
   return value: value of the specified module controller.
*/
int sv_get_module_ctl_value( int slot, int mod_num, int ctl_num, int scaled );

/*
   sv_set_module_ctl_value() - send the value to the specified module controller; (sv_send_event() will be used internally)
*/
int sv_set_module_ctl_value( int slot, int mod_num, int ctl_num, int val, int scaled );

/*
*/
int sv_get_module_ctl_min( int slot, int mod_num, int ctl_num, int scaled );
int sv_get_module_ctl_max( int slot, int mod_num, int ctl_num, int scaled );
int sv_get_module_ctl_offset( int slot, int mod_num, int ctl_num ); /* Get display value offset */
int sv_get_module_ctl_type( int slot, int mod_num, int ctl_num ); /* 0 - normal (scaled); 1 - selector (enum); */
int sv_get_module_ctl_group( int slot, int mod_num, int ctl_num );

/*
   sv_new_pattern() - create a new pattern;
   sv_remove_pattern() - remove selected pattern;
*/
int sv_new_pattern( int slot, int clone, int x, int y, int tracks, int lines, int icon_seed, const char* name ); /* USE LOCK/UNLOCK! */
int sv_remove_pattern( int slot, int pat_num ); /* USE LOCK/UNLOCK! */

/*
   sv_get_number_of_patterns() - get the number of pattern slots (not the actual number of patterns).
   The slot can be empty or it can contain a pattern.
   Here is the code to determine that the pattern slot X is not empty: sv_get_pattern_lines( slot, X ) > 0;
*/
int sv_get_number_of_patterns( int slot );

/*
   sv_find_pattern() - find a pattern by name;
   return value: pattern number or -1 (if not found);
*/
int sv_find_pattern( int slot, const char* name );

/*
   sv_get_pattern_x/y() - get pattern position;
   return value:
     x - line number (horizontal position on the timeline);
     or
     y - vertical position on the timeline;
*/
int sv_get_pattern_x( int slot, int pat_num );
int sv_get_pattern_y( int slot, int pat_num );

/*
   sv_set_pattern_xy() - set pattern position;
   Parameters:
     x - line number (horizontal position on the timeline);
     y - vertical position on the timeline;
*/
int sv_set_pattern_xy( int slot, int pat_num, int x, int y ); /* USE LOCK/UNLOCK! */

/*
   sv_get_pattern_tracks/lines() - get pattern size;
   return value:
     tracks - number of pattern tracks;
     or
     lines - number of pattern lines;
*/
int sv_get_pattern_tracks( int slot, int pat_num );
int sv_get_pattern_lines( int slot, int pat_num );

/*
*/
int sv_set_pattern_size( int slot, int pat_num, int tracks, int lines ); /* USE LOCK/UNLOCK! */

/*
*/
const char* sv_get_pattern_name( int slot, int pat_num );
int sv_set_pattern_name( int slot, int pat_num, const char* name ); /* USE LOCK/UNLOCK! */

/*
   sv_get_pattern_data() - get the pattern buffer (for reading and writing)
   containing notes (events) in the following order:
     line 0: note for track 0, note for track 1, ... note for track X;
     line 1: note for track 0, note for track 1, ... note for track X;
     ...
     line X: ...
   Example:
     int pat_tracks = sv_get_pattern_tracks( slot, pat_num ); //number of tracks
     sunvox_note* data = sv_get_pattern_data( slot, pat_num ); //get the buffer with all the pattern events (notes)
     sunvox_note* n = &data[ line_number * pat_tracks + track_number ];
     ... and then do someting with note n ...
*/
sunvox_note* sv_get_pattern_data( int slot, int pat_num );

/*
   sv_set_pattern_event() - write the pattern event to the cell at the specified line and track
   nn,vv,mm,ccee,xxyy are the same as the fields of sunvox_note structure.
   Only non-negative values will be written to the pattern.
   Return value: 0 (sucess) or negative error code.
*/
int sv_set_pattern_event( int slot, int pat_num, int track, int line, int nn, int vv, int mm, int ccee, int xxyy );

/*
   sv_get_pattern_event() - read a pattern event at the specified line and track
   column (field number):
      0 - note (NN);
      1 - velocity (VV);
      2 - module (MM);
      3 - controller number or effect (CCEE);
      4 - controller value or effect parameter (XXYY);
   Return value: value of the specified field or negative error code.
*/
int sv_get_pattern_event( int slot, int pat_num, int track, int line, int column );

/*
   sv_pattern_mute() - mute (1) / unmute (0) specified pattern;
   negative values are ignored;
   return value: previous state (1 - muted; 0 - unmuted) or -1 (error);
*/
int sv_pattern_mute( int slot, int pat_num, int mute ); /* USE LOCK/UNLOCK! */

/*
   SunVox engine uses system-provided time space, measured in system ticks (don't confuse it with the project ticks).
   These ticks are required for parameters of functions such as sv_audio_callback() and sv_set_event_t().
   Use sv_get_ticks() to get current tick counter (from 0 to 0xFFFFFFFF).
   Use sv_get_ticks_per_second() to get the number of system ticks per second.
*/
uint32_t sv_get_ticks( void );
uint32_t sv_get_ticks_per_second( void );

/*
   sv_get_log() - get the latest messages from the log
   Parameters:
     size - max number of bytes to read.
   Return value: pointer to the null-terminated string with the latest log messages.
*/
const char* sv_get_log( int size );

]])
local src_path = love.filesystem.getSource()

local sv = ffi.load(src_path .. "/lib/sunvox.so")

return sv
