% Langsec Workshop 2017: Writing parsers like it is 2017
% Pierre Chifflier - Geoffroy Couprie
% 2017/05/25

# Who

* Security and QA at Clever Cloud
* Freelance consultant, security and architecture
* <span class="twitter">@gcouprie</span>
* geoffroy.couprie@clever-cloud.com

* Head of the Detection Research lab at ANSSI
* Security, Compilers, Languages, Free Software
* <span class="twitter">@pollux7</span>
* pierre.chifflier@ssi.gouv.fr

<aside class="notes">
rust main language for nearly a year now

we're pushing some Rust in production now
ssh jail, proxy, git subsystems
</details>

# Writing parsers is hard

<img src="img/chart_vulns.png" height="60%" class="centered" />

*(source: Google OSS-Fuzz)*

# Writing new code

- we can write new code in safer languages
- we can make new parsers with better techniques
- we can plan our code for formal proofs

# But...

most of the existing code is written in unsafe
languages with weak development practices

#

## Typically

- in C or C++
- handwritten parsers
- highly coupled code
- hard to test and refactor

# We cannot rewrite those projects entirely

- often between 10k and 1M lines of code
- old code base
- huge domain knowledge

# We cannot rewrite those projects entirely

- big risk of regressions
- politics

# Solution

Surgically replacing the unsafe parts of the code

# Shopping list

- a language that can call C (good FFI support)
- a language that can be called by C
- if possible, no garbage collection
- "fast enough"

<aside class="notes">
fast enough means nearly as fast as C, to convince C developers
</details>

# Rust

<img src="img/rust-logo-512x512.png" class="centered" />

<aside class="notes">
- Rust makes memory handling easier
- slices are really useful
- easy FFI
</details>

# Rust

- Managed memory (and no garbage collector)
- Type safety
- Thread safety
- Efficient: native code, zero-copy
- Easy integration with C/C++
- Isolation of *unsafe* code
- Minimal runtime
- Good community

# Parser combinators

Using a safe language is not enough:
```rust
ptr_ip = &s[ x .. y ];

x = s.find("[").unwrap() + 1;
y = x + 26;
ptr_datetime = &s[ x .. y ];

x = y + s[ y .. l ].find('"').unwrap() + 1;
y = x + s[ x .. l ].find(' ').unwrap();
ptr_method = &s[ x .. y ];

x = y + 1;
y = x + s[ x .. l ].find(' ').unwrap() - 1;
ptr_path = &s[ x .. y ];

x = y + 7;
y = x + s[ x .. l ].find('"').unwrap();
ptr_http_version = &s[ x .. y ];
```

- Fragile code, error-prone
- No error handling
- Using `unwrap()` is wrong here (risk of `panic`)

<aside class="notes">
Unreadable, unmaintainable
</details>

# nom

<img src="img/cookie-monster.gif" class="centered" />


# what is nom?

- parser combinators
- macros

<aside class="notes">
I needed an easy way to write parsers
parser combinators are simple, they're just functions
easy to experiment

started in July 2014 (in another repo)
no impl Trait
no lifetime elision
closures?

fighting lifetime issues was (still is) a pain
compilation times
(well, compilation times can be hairy in rust, like the alt! bug)
</details>

# Basic types

```rust
fn parser<Input, Output, Error>(input: Input) -> IResult<Input, Output, Error>
```

```rust
pub enum IResult<Input, Output, CustomError=u32> {
  Done( Input, Output ),
  Error( Err<Input, CustomError> ),
  Incomplete( Needed )
}
```

<aside class="notes">
EXPLAIN

Done contains output and remaining input
</details>

# MACROS!!!

```rust
named!(data, terminated!( alpha, digit ));
```

<aside class="notes">
composition of functions

take time to explain here

macros are easy to write
a bit annoying to debug when you don't get the right types
some patterns are hard to express, like the permutation parser
parser combinators are easy to express
</details>

# Generated code

```rust
fn data<'a>(input: &'a [u8]) -> IResult<&'a [u8], &'a [u8], u32> {
  match alpha(input) {
    Done(i, o) => {
      match digit(i) {
        Done(i2, _) => Done(i2, o),
        Incomplete(Needed::Size(i)) =>
          Incomplete(Needed::Size(input.input_len() - i.input_len() + i)),
        e => e,
      }
    },
    e => e
  }
}
```

# Actual generated code

```rust
fn data<'a>(i: &'a [u8]) -> ::nom::IResult<&'a [u8], &[u8], u32> {
    match {
              {
                  use nom::InputLength;
                  match alpha(i) {
                      ::nom::IResult::Error(e) =>
                      ::nom::IResult::Error(e),
                      ::nom::IResult::Incomplete(::nom::Needed::Unknown)
                      =>
                      ::nom::IResult::Incomplete(::nom::Needed::Unknown),
                      ::nom::IResult::Incomplete(::nom::Needed::Size(i))
                      =>
                      ::nom::IResult::Incomplete(::nom::Needed::Size(0usize
                                                                         +
                                                                         i)),
                      ::nom::IResult::Done(i, o) => {
                          {
                              use nom::InputLength;
                              match digit(i) {
                                  ::nom::IResult::Error(e) =>
                                  ::nom::IResult::Error(e),
                                  ::nom::IResult::Incomplete(::nom::Needed::Unknown)
                                  =>
                                  ::nom::IResult::Incomplete(::nom::Needed::Unknown),
                                  ::nom::IResult::Incomplete(::nom::Needed::Size(i))
                                  =>
                                  ::nom::IResult::Incomplete(::nom::Needed::Size(0usize
                                                                                     +
                                                                                     ((i).input_len()
                                                                                          -
                                                                                          i.input_len())
                                                                                     +
                                                                                     i)),
                                  ::nom::IResult::Done(i, o) => {
                                      ::nom::IResult::Done(i, (o, o))
                                  }
                              }
                          }
                      }
                  }
              }
          } {
        ::nom::IResult::Error(a) => ::nom::IResult::Error(a),
        ::nom::IResult::Incomplete(i) => ::nom::IResult::Incomplete(i),
        ::nom::IResult::Done(remaining, (_, o)) => {
            ::nom::IResult::Done(remaining, o)
        }
    }
}
```

# features

INSERT GOOD THINGS ABOUT NOM HERE

# Integrating Rust in existing C projects

- VLC media player
- suricata

# VideoLAN

<img src="img/largeVLC.png" class="centered" />

<aside class="notes">
what I do at VideoLAN

VLC handles most audio, video and streaming formats
</details>

# VLC media player

- dozens of formats and protocols
- written in C and C++

# How VLC works

<img src="img/vlc-pipeline.png" class="centered" />

<aside class="notes">
The pipeline

access -> demux (=> audio and video streams) -> decode -> filter -> (encode -> stream) | (video and audio out)
</details>

# Code architecture

<img src="img/vlc-arch.png" class="centered" />

<aside class="notes">
- libVLCCore: handles module loading, playlist, synchronization, the whole pipeline
- libVLC: a layer above libVLCCore for external applications
- vlc: a small executable calling libVLC
</details>

# Let's build a VLC plugin in Rust

- integrating a FLV parser written with nom
- with an ABI compatible DLL
- built with autotools

# Lifetime of a VLC module

- libVLCCore looks for dynamic libraries in a specified folder
- those dynamic libraries expose three functions:
  - vlc_entry__VERSION (example: vlc_entry__3_0_0a)
  - vlc_entry_copyright__VERSION
  - vlc_entry_license__VERSION
- libVLCCore calls vlc_entry__VERSION and the module registers callbacks
- libVLCCore calls the module when needed

<aside class="notes">
so we don't control anything from the module, we just take orders
</details>


# The plan

- reproduce needed structures from VLC headers
- link to libVLCCore and import useful functions
- reproduce the module registration code
- write a FLV parser
- parse stuff

# Reproducing structures

```C
struct demux_t
{
    VLC_COMMON_MEMBERS

    module_t    *p_module;

    char        *psz_access;
    char        *psz_demux;
    char        *psz_location;
    char        *psz_file;

    union {
        stream_t *s;
        demux_t *p_next;
    };

    /* es output */
    es_out_t *out; /* our p_es_out */

    [...]
```

<aside class="notes">
VLC uses a sort of object-like structure, with objects sharing (via a macro) some common members
taking some inspiration from rust-openssl and others here: put the structure definitions and function imports in a separate file, make safer wrappers above them, using Rust types

servo-bindgen can apparently do the job!
</details>

# C structure to Rust

```rust
#[repr(C)]
pub struct vlc_object_t {
  pub psz_object_type: *const c_char,
  pub psz_header:      *mut c_char,
  pub i_flags:         c_int,
  pub b_force:         bool,
  pub p_libvlc:        *mut libvlc_int_t,
  pub p_parent:        *mut vlc_object_t,
}

#[repr(C)]
pub struct demux_t<T> {
  //VLC_COMMON_MEMBERS
  pub psz_object_type: *const c_char,
  pub psz_header:      *mut c_char,
  pub i_flags:         c_int,
  pub b_force:         bool,
  pub p_libvlc:        *mut libvlc_int_t,
  pub p_parent:        *mut vlc_object_t,

  pub p_module:        *mut module_t,

  pub psz_access:      *mut c_char,
  pub psz_demux:       *mut c_char,
  pub psz_location:    *mut c_char,
  pub psz_file:        *mut c_char,

  pub s:               *mut stream_t,
  pub out:             *mut es_out_t,
  pub pf_demux:        Option<extern "C" fn(*mut demux_t<T>) -> c_int>,
  pub pf_control:      Option<extern "C" fn(*mut demux_t<T>, c_int, *const va_list) -> c_int>,

  // 'info' nested struct. Can we do that with Rust FFI?
  pub i_update:        c_uint,
  pub i_title:         c_int,
  pub i_seekpoint:     c_int,

  //FIXME: p_sys contains a pointer to a module specific structure, make it generic?
  pub p_sys:           *mut T,

  pub p_input:         *mut input_thread_t,
}
```

# Importing functions

```rust
mod ffi {
  #[link(name = "vlccore")]
  extern {
    pub fn stream_Read(
      stream: *mut stream_t,
      buf: *const c_void,
      size: size_t) -> ssize_t;
  }
}
```

<aside class="notes">
try to add a function -> you miss a struct -> add the struct -> you need other structs, etc
</details>

# Writing safer wrappers

```rust
pub fn stream_Read(stream: *mut stream_t, buf: &mut [u8]) -> ssize_t {
  unsafe {
    ffi::stream_Read(stream, buf.as_mut_ptr() as *const c_void, buf.len())
  }
}
```

# preparing a VLC module in C

```C
static int  Open ( vlc_object_t * );
static void Close( vlc_object_t * );

vlc_module_begin ()
    set_description( N_("WAV demuxer") )
    set_category( CAT_INPUT )
    set_subcategory( SUBCAT_INPUT_DEMUX )
    set_capability( "demux", 142 )
    set_callbacks( Open, Close )
vlc_module_end ()
```

<aside class="notes">
those are macros
</details>

# expanded

```C
int vlc_entry__3_0_0a (vlc_set_cb, void *);
int vlc_entry__3_0_0a (vlc_set_cb vlc_set, void *opaque) {
    module_t *module;
    module_config_t *config = ((void*)0);
    if (vlc_set (opaque, ((void*)0), VLC_MODULE_CREATE, &module))
        goto error;
    if (vlc_set (opaque, module, VLC_MODULE_NAME, ("modules/demux/wav.c")))
        goto error;
    if (vlc_set (opaque, module, VLC_MODULE_DESCRIPTION,
      (const char *)(N_("WAV demuxer"))))
        goto error;
    vlc_set (opaque, ((void*)0), VLC_CONFIG_CREATE, (0x06), &config);
    vlc_set (opaque, config, VLC_CONFIG_VALUE, (int64_t)(4));
    vlc_set (opaque, ((void*)0), VLC_CONFIG_CREATE, (0x07), &config);
    vlc_set (opaque, config, VLC_CONFIG_VALUE, (int64_t)(403));
    if (vlc_set (opaque, module, VLC_MODULE_CAPABILITY, (const char *)("demux")) ||
        vlc_set (opaque, module, VLC_MODULE_SCORE, (int)(142)))
        goto error;
    if (vlc_set (opaque, module, VLC_MODULE_CB_OPEN, Open) ||
        vlc_set (opaque, module, VLC_MODULE_CB_CLOSE, Close))
        goto error;
    (void) config;
    return 0;

  error:
    return -1;
}
```

<aside class="notes">
taking apart code loading and APIs is where you spend the most time
</details>

# Writing the module registration

```rust
#[allow(non_snake_case)]
#[no_mangle]
pub unsafe extern fn vlc_entry__3_0_0a(
    vlc_set: unsafe extern fn(*mut c_void, *mut c_void, c_int, ...) -> c_int,
    opaque: *mut c_void) -> c_int {
  let module: *mut c_void = 0 as *mut c_void;
  if vlc_set(opaque, 0 as *mut c_void, VLCModuleProperties::VLC_MODULE_CREATE as i32,
             &module) != 0 { return -1; }
  if vlc_set(opaque, module, VLCModuleProperties::VLC_MODULE_NAME as i32,
             PLUGIN_NAME.as_ptr()) != 0 { return -1; }
  let desc = b"FLV demuxer written in Rust\0";
  if vlc_set(opaque, module, VLCModuleProperties::VLC_MODULE_DESCRIPTION as i32,
             desc.as_ptr()) != 0 { return -1; }
  let capability = b"demux\0";
  if vlc_set(opaque, module, VLCModuleProperties::VLC_MODULE_CAPABILITY as i32,
             capability.as_ptr()) != 0 { return -1; }
  if vlc_set(opaque, module, VLCModuleProperties::VLC_MODULE_SCORE as i32, 999) != 0 {
    return -1;
  }
  let p_open: extern "C" fn(*mut demux_t<demux_sys_t>) -> c_int =
    transmute(open as extern "C" fn(_) -> c_int);
  if vlc_set(opaque, module, VLCModuleProperties::VLC_MODULE_CB_OPEN as i32, p_open) != 0 {
    return -1;
  }
  let p_close: extern "C" fn(*mut demux_t<demux_sys_t>) = transmute(close as extern "C" fn(_));
  if vlc_set(opaque, module, VLCModuleProperties::VLC_MODULE_CB_CLOSE as i32, p_close) != 0 {
    return -1;
  }
  0
}
```

#

<img class="centered" src="img/wtf.gif" style="height: 500px" />

# after some macro work

```rust
vlc_module!(vlc_entry__3_0_0a,
  set_name("inrustwetrust")
  set_description("FLV demuxer written in Rust")
  set_capability("demux", 999)
  set_callbacks(open, close)
);
```

# Write a FLV parser

```rust
named!(pub header<Header>,
  do_parse!(
                tag!("FLV")
    >> version: be_u8
    >> flags:   be_u8
    >> offset:  be_u32
    >> ( Header {
        version: version,
        audio:   flags & 4 == 4,
        video:   flags & 1 == 1,
        offset:  offset
    } )
  )
);
```

<aside class="notes">
show the do_parse syntax that could replace it
</details>

# Parse the header

```rust
extern "C" fn open(p_demux: *mut demux_t<demux_sys_t>) -> c_int {
  let p_demux = unsafe { &mut (*p_demux) };
  let sl = stream_Peek(p_demux.s, 9);

  if let IResult::Done(_,h) = flavors::parser::header(sl) {

    vlc_Log!(p_demux, LogType::Info, PLUGIN_NAME, "FOUND FLV FILE\n
      version: {}\nhas_audio: {}\n has_video: {}\noffset: {}\n",
    h.version, h.audio, h.video, h.offset);

    stream_Seek(p_demux.s, h.offset as uint64_t);

    p_demux.pf_demux   = Some(demux);
    p_demux.pf_control = Some(control);
    p_demux.p_sys = Box::into_raw(Box::new(demux_sys_t {
      i_pos: h.offset as usize,
      i_size: 0,
      video_initialized: false,
      video_es_format: unsafe { zeroed() },
      video_es_id: 0 as *mut c_void,
      audio_initialized: false,
      audio_es_format: unsafe { zeroed() },
      audio_es_id: 0 as *mut c_void,
    }));

    return 0;
  }

  -1
}
```

<aside class="notes">
proceed step by step. Parse a bit, then advance, log everything
</details>

# FLV packets

```rust
named!(pub tag_header<TagHeader>,
  chain!(
    tag_type: switch!(be_u8,
      8  => value!(TagType::Audio) |
      9  => value!(TagType::Video) |
      18 => value!(TagType::Script)
    )                                ~
    data_size:          be_u24       ~
    timestamp:          be_u24       ~
    timestamp_extended: be_u8        ~
    stream_id:          be_u24       ,
    || {
      TagHeader {
        tag_type:  tag_type,
        data_size: data_size,
        timestamp: ((timestamp_extended as u32) << 24) + timestamp,
        stream_id: stream_id,
      }
    }
  )
);
```

<aside class="notes">
the tag header is preceded by a 4 bytes big endian uint indicating the previous tag's size
</details>

# Now, begin parsing

```rust
extern "C" fn demux(p_demux: *mut demux_t<demux_sys_t>) -> c_int {
  let p_demux = unsafe { &mut (*p_demux) };
  let p_sys = unsafe { &mut (*p_demux.p_sys) };

  let mut header = [0u8; 15];
  let sz = stream_Read(p_demux.s, &mut header);
  if sz < 15 {
    if sz == 4 {
      vlc_Log!(p_demux, LogType::Info, PLUGIN_NAME, "end of stream");
      return 0;
    } else {
      vlc_Log!(p_demux, LogType::Info, PLUGIN_NAME, "could not read header:\n{}",
      &header[..sz].to_hex(8));
      return -1;
    }
  }
```

<aside class="notes">
the to_hex method is invaluable: show a hexdump od the slice
</details>

# Audio data header

```rust
//stored in 1 byte
pub struct AudioDataHeader {
  pub sound_format: SoundFormat,
  pub sound_rate:   SoundRate,
  pub sound_size:   SoundSize,
  pub sound_type:   SoundType,
}
```

# Audio data header parsing

```rust
pub fn audio_data_header(input: &[u8]) -> IResult<&[u8], AudioDataHeader> {
  if input.len() < 1 {
    return IResult::Incomplete(Needed::Size(1));
  }

  let (remaining, (sformat, srate, ssize, stype)) = try_parse!(input, bits!(
    tuple!(
      switch!(take_bits!(u8, 4),
        0  => value!(SoundFormat::PCM_BE)
      | 1  => value!(SoundFormat::ADPCM)
      | 2  => value!(SoundFormat::MP3)
      | 3  => value!(SoundFormat::PCM_LE)
      | 4  => value!(SoundFormat::NELLYMOSER_16KHZ_MONO)
      | 5  => value!(SoundFormat::NELLYMOSER_8KHZ_MONO)
      | 6  => value!(SoundFormat::NELLYMOSER)
      | 7  => value!(SoundFormat::PCM_ALAW)
      | 8  => value!(SoundFormat::PCM_ULAW)
      | 10 => value!(SoundFormat::AAC)
      | 11 => value!(SoundFormat::SPEEX)
      | 14 => value!(SoundFormat::MP3_8KHZ)
      | 15 => value!(SoundFormat::DEVICE_SPECIFIC)
      ),
      switch!(take_bits!(u8, 2),
        0 => value!(SoundRate::_5_5KHZ)
      | 1 => value!(SoundRate::_11KHZ)
      | 2 => value!(SoundRate::_22KHZ)
      | 3 => value!(SoundRate::_44KHZ)
      ),
      switch!(take_bits!(u8, 1),
        0 => value!(SoundSize::Snd8bit)
      | 1 => value!(SoundSize::Snd16bit)
      ),
      switch!(take_bits!(u8, 1),
        0 => value!(SoundType::SndMono)
      | 1 => value!(SoundType::SndStereo)
      )
    )
  ));

  IResult::Done(&input[1..], AudioDataHeader {
    sound_format: sformat,
    sound_rate:   srate,
    sound_size:   ssize,
    sound_type:   stype,
  })
}
```
# Check the header (audio case)

```rust
if let IResult::Done(_remaining, header) = parser::tag_header(&header[4..]) {
  match header.tag_type {
    TagType::Audio => {
      let mut a_header = [0u8; 1];
      if stream_Read(p_demux.s, &mut a_header) < 1 { return -1; }

      if let IResult::Done(_, audio_header) = parser::audio_data_header(&a_header) {
        // <initialize demuxer with audio format info>

        let p_block: *mut block_t = stream_Block(p_demux.s, (header.data_size - 1) as size_t);
        if p_block == 0 as *mut block_t { return -1; }
        let p_block = unsafe { &mut(*p_block) };

        let out_ref = p_demux.out;
        unsafe {
          to_va_list!(move |v: rs_va_list::va_list| {
            let pf_control: fn(*mut c_void, c_int, rs_va_list::va_list) =
              transmute((*out_ref).pf_control);
            pf_control(out_ref as *mut c_void, ES_OUT_SET_PCR, v);
          }, p_block.i_pts);
        }
        es_out_Send(p_demux.out, p_sys.audio_es_id, p_block);
        return 1;
      } else { return -1; }
```

<aside class="notes">
there's a hack with va_list: https://github.com/GuillaumeGomez/va_list-rs

sometimes, you can't write rust-y code, you need to adapt to the APIs
</details>

# Demo

# Now, the build system

<img src="img/autotools.jpg" class="centered" />

<aside class="notes">
we have a VLC plugin that we can drop in the module folder, can we build it inside VLC's tree instead?

VLC uses the autotools heavily, and builds the module correctly for the right platform
automatically (with libtool, etc)
</details>

# Integrating with autotools

- rustc knows how to make libraries
- libtool knows how to make libraries
- let's make an object file and give it to libtool

# First, check for cargo and Rust

```Makefile
AC_ARG_ENABLE(cargo,
    [AS_HELP_STRING([--enable-cargo],
      [Enable rust-based plugins that require cargo to build (default disabled)])])

AS_IF([test "${enable_cargo}" = "yes"], [
  AC_CHECK_PROG(CARGO, [cargo], [yes], [no])
  AC_CHECK_PROG(RUSTC, [rustc], [yes], [no])

  AS_IF([test "$CARGO" != "yes" -o "$RUSTC" != "yes"], [
    AC_MSG_FAILURE("Rust based plugins cannot be built $CARGO $RUSTC")
  ])
  VLC_ADD_PLUGIN([rust_plugin])
])
```

# Declaring and building a Rust module

```Makefile
librust1_plugin_la_SOURCES = ""

librust_plugin.a: demux/rust/src/lib.rs
	cd $(srcdir)/demux/rust
	CARGO_TARGET_DIR="$(abs_builddir)/.libs/" cargo build -v
	mv $(abs_builddir)/.libs/debug/$@ $@

rust_plugin.o: demux/rust/src/lib.rs
	cd $(srcdir)/demux/rust
	CARGO_TARGET_DIR="$(abs_builddir)/.libs/" cargo rustc -- --emit obj
	mv $(abs_builddir)/.libs/debug/$@ $@

am_librust1_plugin_la_OBJECTS = rust_plugin.o
librust1_plugin_la_LIBADD = librust_plugin.a

demux_LTLIBRARIES += librust1_plugin.la
```

<aside class="notes">
we generate an obj file and give it to the build system
</details>















# More info

* Nom: https://github.com/Geal/nom
* slides: http://dev.unhandledexpression.com/slides/rust-belt-rust-2016/vlc
* flavors: https://github.com/Geal/flavors
* helper library: https://github.com/Geal/vlc_module.rs
* the module: https://github.com/Geal/rust-vlc-demux
* twitter: <span class="twitter">@gcouprie</span>


# Thanks!

# Parsers ?

# STOP

#

#

#########################################




# VLC media player vulnerabilities

- invalid freeing of pointers in 3GP (CVE-2015-5949)
- crash with divide by zero in ASF (CVE-2014-1684)
- buffer overflow for Dirac streams (CVE-2014-9629)
- invalid memory access in RTP (CVE-2014-9630)
- buffer overflows in MP4 demuxer (CVE-2014-9626, CVE-2014-9627, CVE-2014-9628)

<aside class="notes">
handling multiple formats is dangerous. MP4 has a lot of flaws, but not the MKV demuxer

fuzzing
</details>

# Format vulnerabilities

* C
* manual parsing
* weird formats

<aside class="notes">
a good developer would avoid those issues
But how can we fight the urge to write vulnerable code?
</details>

# We need a practical solution

- hard to do mistakes
- memory safe
- embeddable in C (no runtime or GC)
- efficient, streaming

<aside class="notes">
if not for the "embeddable", I would write some haskell
</details>

# Yay! Rust!

<img src="img/rust-logo-512x512.png" class="centered" />

<aside class="notes">
- Rust makes memory handling easier
- slices are really useful
- easy FFI
</details>

# nom features

<img src="img/colorful-ftyp.png" />

- strings (&str), byte slices and bit streams parsing
- common combinators (many, pair, peek, etc)
- regular expressions
- advanced error management

# benefits

- works on all Rust versions since 1.0
- no syntax extensions, no impl Trait
- supports no_std
- can be as fast as C parsers
- designed with streaming in mind
- very easy to extend (it's just functions!)

# nom 2.0 highlights: whitespace parsing

```rust
named!(key_value<(&str,JsonValue)>,
  ws!(
    separated_pair!(
      string,
      tag!(":"),
      value
    )
  )
);
```

# nom 2.0 highlights: permutation combinator

```rust
named!(perm<&str,(&str, &str, &str)>,
  permutation!(tag!("abcd"), tag!("efg"), tag!("hi"))
);

assert_eq!(perm("efghiabcd"), Done("", ("abcd", "efg", "hi"));
```

# nom 2.0 highlights: do_parse

```rust
named!(tag_length_value,
  do_parse!(
            tag!( &[ 42u8 ][..] ) >>
    length: be_u8                 >>
    bytes:  take!(length)         >>
    (bytes)
  )
);
```

# nom 2.0 highlights: custom input types

- not limited to &[u8] and &str anymore
- can work with iterators
- can work with ropes based structures
- will allow SIMD based parsing

# nom 2.0 highlights

- tag_no_case: case independent comparison
- &str and &[u8] specific combinators were merged
- big cleanup and breaking changes
- simple VS verbose error management
- 30% to 50% performance gain for most parsers

# VLC media player

<img src="img/largeVLC.png" class="centered" />

# How VLC works

<img src="img/vlc-pipeline.png" class="centered" />

<aside class="notes">
The pipeline

access -> demux (=> audio and video streams) -> decode -> filter -> (encode -> stream) | (video and audio out)
</details>

# Code architecture

<img src="img/vlc-arch.png" class="centered" />

<aside class="notes">
- libVLCCore: handles module loading, playlist, synchronization, the whole pipeline
- libVLC: a layer above libVLCCore for external applications
- vlc: a small executable calling libVLC
</details>

# Lifetime of a VLC module

- libVLCCore looks for dynamic libraries in a specified folder
- those dynamic libraries expose three functions:
  - vlc_entry__VERSION (example: vlc_entry__3_0_0a)
  - vlc_entry_copyright__VERSION
  - vlc_entry_license__VERSION
- libVLCCore calls vlc_entry__VERSION and the module registers callbacks
- libVLCCore calls the module when needed

<aside class="notes">
so we don't control anything from the module, we just take orders
</details>


# The plan

- reproduce needed structures from VLC headers
- link to libVLCCore and import useful functions
- reproduce the module registration code
- write a FLV parser
- parse stuff


# Summing up

- work a lot on the build system
- isolate unsafe APIs
- the parser is the easiest part
- we don't own everything

# Next steps

- implement seeking
- merging it in the VLC repository
- predownload dependencies with cargo-vendor
- complete the libVLCCore imports
- more formats

# Greetings

- thanks to Guillaume Gomez (imperio) for his help on the parser and the plugin
- thanks to Luca Barbato (lu-zero) for solving the build system issues

# More info

* Nom: https://github.com/Geal/nom
* slides: http://dev.unhandledexpression.com/slides/rust-belt-rust-2016/vlc
* flavors: https://github.com/Geal/flavors
* helper library: https://github.com/Geal/vlc_module.rs
* the module: https://github.com/Geal/rust-vlc-demux
* twitter: <span class="twitter">@gcouprie</span>


<aside class="notes">
if you want some stickers...
</details>

# Thanks!

# Parsers ?

* Trop de vulnérabilités
* Difficile à maintenir
* Marre de les réécrire pour tous les projets

# Langages et sécurité

![Alt text](img/troll.jpg)

* C: trop facile de se rater
* Python: trop lent
* OCaml: trop fonctionnel
* Ruby: lol

# Un peu de C

```c
#define MAXLEN 4096

int myparse(int fd)
{
  uint32_t len;
  int rc;
  char *ptr;

  rc = read_u32(fd, &len);
  if (rc < 0) { return -1; };
  if (len > MAXLEN) { return -1; };

  ptr = malloc(len);
  rc = read(fd, ptr, len);
  if (rc < 0 || rc != len) { return -1; };

  return try_parse(ptr,len);
}
```

# Rust & Security

* Non-executable Stack yes
* ASLR: yes
* RELRO: possible (not by default)
* Integer overflow:
    * yes (debug)
    * no (release)
* explicit types or operations can be used

# Suricata

<img src="img/suricata.jpg" class="centered" />

* <a href="https://suricata-ids.org/">Suricata</a>: open source network threat detection engine
* Implements a lot of parsers
* Multi-threaded, fast

# Hardening Suricata

<img src="img/meerkat_helmet.jpg" class="centered" />

* Isolate critical functions (parsing)
* Use existing code (detection, etc.)
* Multi-threaded, fast

# Méthodologie

<img src="img/tenor.gif" class="centered" />

* Écrire des parseurs indépendants
* En Rust 'pur' (pas de code unsafe)
* En utilisant `nom` (cf. plus loin)
* Définir la communication C-Rust
* Écrire une abstraction Suricata
* Isolation du code unsafe
* Remplacement du parseur dans Suricata

# Parser combinators (2)

```rust
#[derive(Debug,PartialEq,Eq)]
pub struct Header {
  pub version: u8,
  pub audio:   bool,
  pub video:   bool,
  pub offset:  u32,
}

named!(pub header<Header>,
  do_parse!(
    tag!("FLV") >>
    version: be_u8       >>
    flags:   be_u8       >>
    offset:  be_u32      >>
    (Header {
      version: version,
      audio:   flags & 4 == 4,
      video:   flags & 1 == 1,
      offset:  offset
    })
  )
);
```

* [nom](https://github.com/Geal/nom) génère le code du parseur Rust
* Le code inclut la gestion d'erreur

# Parser combinators (3)

```rust
named!(pub parse_ntp_key_mac<(u32,&[u8])>,
    complete!(pair!(be_u32,take!(16)))
    );

  named!(pub parse_ntp<NtpPacket>,
      do_parse!(
        b0: bits!(
          tuple!(take_bits!(u8,2),take_bits!(u8,3),take_bits!(u8,3))
          )
        >> st: be_u8
        >> pl: be_i8
        >> pr: be_i8
        >> rde: be_u32
        >> rdi: be_u32
        >> rid: be_u32
        >> tsr: be_u64
        >> tso: be_u64
        >> tsv: be_u64
        >> tsx: be_u64
        >> auth: opt!(parse_ntp_key_mac)

```

* Chaque parseur peut être utilisé dans un autre
* Exemples d'utilité: TLS -> X.509 -> DER, PE -> PKCS7 -> DER, SNMP -> BER

# TLS & RFC

- [RFC 2246](https://tools.ietf.org/html/rfc2246): The TLS Protocol Version 1.0
- [RFC 4346](https://tools.ietf.org/html/rfc4346): The Transport Layer Security (TLS) Protocol Version 1.1
- [RFC 4366](https://tools.ietf.org/html/rfc4366): Transport Layer Security (TLS) Extensions
- [RFC 4492](https://tools.ietf.org/html/rfc4492): Elliptic Curve Cryptography (ECC) Cipher Suites for Transport Layer Security (TLS)
- [RFC 4507](https://tools.ietf.org/html/rfc4507): Transport Layer Security (TLS) Session
Resumption without Server-Side State
- [RFC 5077](https://tools.ietf.org/html/rfc5077): Transport Layer Security (TLS) Session
Resumption without Server-Side State
- [RFC 5246](https://tools.ietf.org/html/rfc5246): The Transport Layer Security (TLS) Protocol Version 1.2
- [RFC 5430](https://tools.ietf.org/html/rfc5430): Suite B Profile for Transport Layer Security (TLS)
- [RFC 5746](https://tools.ietf.org/html/rfc5746): Transport Layer Security (TLS) Renegotiation Indication Extension
- [RFC 6066](https://tools.ietf.org/html/rfc6066): Transport Layer Security (TLS) Extensions: Extension Definitions
- [RFC 6520](https://tools.ietf.org/html/rfc6520): Transport Layer Security (TLS) and
Datagram Transport Layer Security (DTLS) Heartbeat Extension
- [RFC 6961](https://tools.ietf.org/html/rfc6961): The Transport Layer Security (TLS)
Multiple Certificate Status Request Extension
- [RFC 6962](https://tools.ietf.org/html/rfc6962): Certificate Transparency
- [RFC 7027](https://tools.ietf.org/html/rfc7027): Elliptic Curve Cryptography (ECC) Brainpool Curves
for Transport Layer Security (TLS)
- [RFC 7301](https://tools.ietf.org/html/rfc7301): Transport Layer Security (TLS)
Application-Layer Protocol Negotiation Extension
- [RFC 7366](https://tools.ietf.org/html/rfc7366): Encrypt-then-MAC for Transport Layer Security (TLS) and
Datagram Transport Layer Security (DTLS)
- [RFC 7627](https://tools.ietf.org/html/rfc7627): Transport Layer Security (TLS) Session Hash and
Extended Master Secret Extension
- [RFC 7685](https://tools.ietf.org/html/rfc7685): A Transport Layer Security (TLS) ClientHello Padding Extension
- [RFC 7919](https://tools.ietf.org/html/rfc7919): Negotiated Finite Field Diffie-Hellman Ephemeral Parameters
for Transport Layer Security (TLS)
- [draft-agl-tls-nextprotoneg-03](https://tools.ietf.org/html/draft-agl-tls-nextprotoneg-03): Transport Layer Security (TLS) Next Protocol Negotiation Extension

# TLS parser

ServerHello (TLS 1.2)

```rust
pub struct TlsServerHelloContents<'a> {
  pub version: u16,
  pub rand_time: u32,
  pub rand_data: &'a[u8],
  pub session_id: Option<&'a[u8]>,
  pub cipher: u16,
  pub compression: u8,

  pub ext: Option<&'a[u8]>,
}

pub enum TlsMessageHandshake<'a> {
  HelloRequest,
  ClientHello(TlsClientHelloContents<'a>),
  ServerHello(TlsServerHelloContents<'a>),
  ...
}
```

# TLS parser

ServerHello (TLS 1.2)

```rust
named!(parse_tls_handshake_msg_server_hello_tlsv12<TlsMessageHandshake>,
  do_parse!(
    v:         be_u16 >>
    rand_time: be_u32 >>
    rand_data: take!(28) >> // 28 as 32 (aligned) - 4 (time)
    sidlen:    be_u8 >> // check <= 32, can be 0
    error_if!(sidlen > 32, Err::Code(ErrorKind::Custom(128))) >>
    sid:       cond!(sidlen > 0, take!(sidlen as usize)) >>
    cipher:    be_u16 >>
    comp:      be_u8 >>
    ext:       opt!(complete!(length_bytes!(be_u16))) >>
    (
      TlsMessageHandshake::ServerHello(
        TlsServerHelloContents::new(v,rand_time,rand_data,sid,cipher,comp,ext)
      )
    )
  )
);
```

# TLS parser

ServerHello (TLS 1.3)

```rust
named!(parse_tls_handshake_msg_server_hello_tlsv13draft<TlsMessageHandshake>,
  do_parse!(
    v:      be_u16 >>
    random: take!(32) >>
    cipher: be_u16 >>
    ext:    opt!(complete!(length_bytes!(be_u16))) >>
    (
      TlsMessageHandshake::ServerHelloV13(
        TlsServerHelloV13Contents::new(v,random,cipher,ext)
      )
    )
  )
);
```

# Accessor functions

```rust
#[repr(u16)]
pub enum TlsVersion {
  Ssl30 = 0x0300,
  Tls10 = 0x0301,
  Tls11 = 0x0302,
  Tls12 = 0x0303,
  Tls13 = 0x0304,

  Tls13Draft18 = 0x7f12,
}

impl<'a> TlsServerHelloV13Contents<'a> {
  pub fn get_version(&self) -> Option<TlsVersion> {
    TlsVersion::from_u16(self.version)
  }
}

// [...]

let opt_vers = server_hello.get_version();
...
}
```

# Unit tests

La commande `cargo test` lance tous les tests unitaires

```rust
static DATA: &'static [u8] = &[
  0x16, 0x03, 0x03, ...
];

#[test]
fn test_tls_record_serverhello() {
  let expected = TlsPlaintext {
    hdr: TlsRecordHeader {
    record_type: TlsRecordType::Handshake as u8,
                   version: 0x0303,
                   len: 59,
         },
    msg: vec![TlsMessage::Handshake(
             TlsMessageHandshake::ServerHello(
               TlsServerHelloContents {
                version: 0x0303,
                rand_time: 0x57c457da,
                rand_data: &bytes[15..43],
                session_id: None,
                cipher: 0xc02f,
                compression: 0,
                ext: Some(&bytes[49..]),
              })
           )]
  };
  assert_eq!(parse_tls_plaintext(DATA), IResult::Done(empty, expected));
}
```

# Defragmentation

```Rust
pub fn parse_tcp_level<'b>(&mut self, i: &'b[u8]) -> u32 {
  let mut v : Vec<u8>;
  // Check if TCP data is being defragmented
  let tcp_buffer = match self.tcp_buffer.len() {
    0 => i,
      _ => {
        v = self.tcp_buffer.split_off(0);
        // sanity check vector length to avoid memory exhaustion
        // maximum length may be 2^24 (handshake message)
        if self.tcp_buffer.len() + i.len() > 16777216 {
          self.events.push(TlsParserEvents::RecordOverflow as u32);
          return R_STATUS_EVENTS;
        };
        v.extend_from_slice(i);
        v.as_slice()
      },
  };
```

# Machine à état

```Rust
pub enum TlsState {
  None,
  ClientHello,
  AskResumeSession,
  ResumeSession,
  ServerHello,
  ...
}

fn tls_state_transition_handshake(state: TlsState, msg: &TlsMessageHandshake)
  -> Result<TlsState,StateChangeError> {
    match (state,msg) {
      (None,        &ClientHello(ref msg)) => {
        match msg.session_id {
          Some(_) => Ok(AskResumeSession),
            _       => Ok(ClientHello)
        }
      },
        // Server certificate
        (ClientHello, &ServerHello(_))       => Ok(ServerHello),
        (ServerHello, &Certificate(_))       => Ok(Certificate),
        // Server certificate, no client certificate requested
        (Certificate, &ServerKeyExchange(_)) => Ok(ServerKeyExchange),
        // [...]
        // All other transitions are considered invalid
        _ => Err(InvalidTransition),
```

# Communication C-Rust

Sens C vers Rust
```C
extern uint32_t my_rust_function(uint32_t val);

uint32_t rc = my_rust_function(42);

```

Sens Rust vers C
```Rust
extern "C" fn my_c_function(u32) -> u32;

let rc = my_c_function(42);

```

# Modèle mémoire

* Pour les structures, on peut:
* soit les voir comme des pointeurs opaques (simple)
* soit les définir en un mode compatible (rapide)
* Compatible pour les types de base, sauf les unions

# Bindings

Génération automatique de bindings

* [rusty-cheddar](https://github.com/Sean1708/rusty-cheddar): generate C header files from Rust
* [rusty-binder](https://gitlab.com/rusty-binder/rusty-binder): create Rust bindings for any language
* [corrode](https://github.com/jameysharp/corrode): C to Rust translator
* [rust-bindgen](https://github.com/servo/rust-bindgen): generate Rust FFI bindings to C and C++ libraries

* Ça marche, mais c'est mal: manque de maîtrise, code "sale", etc.
* Convertir ne suffit pas: il faut apprendre les patterns du langage, etc.
* Par contre, `rusty-binder` permet de générer des modules Python, etc.

# Intégration

![Alt text](img/suricata-c-rust.svg)

* Compilation Rust: fournit une archive (`libsuricata-rust.a`) ou `.so` (au choix)
* Compilé statiquement dans Suricata

# Intégration

* Suricata 'voit' le parseur Rust comme du code C
* Rust utilise les fonctions de log, etc. de Suricata

```C
static int Nfs3TcpParseResponse(Flow *f, void *state, AppLayerParserState *pstate,
    uint8_t *input, uint32_t input_len, void *local_data)
{
  uint16_t file_flags = FileFlowToFlags(f, STREAM_TOCLIENT);
  r_nfstcp_setfileflags(1, state, file_flags);

  int r = r_nfstcp_parse(1, input, input_len, state);
  SCLogDebug("r %d", r);
```

# Tests

![Alt text](img/cat_jump_fail.gif)

* Unit tests
* Pcaps
* Fuzzing

# Unit tests

En utilisant `cargo test`

```
Running target/debug/deps/tls_handshake-878885468bffee15

running 15 tests
test tls_handshake::test_tls_message_status_response ... ok
test tls_handshake::test_tls_record_cert_request_ca ... ok
test tls_handshake::test_tls_record_certificate ... ok
test tls_handshake::test_tls_record_cert_request_noca ... ok
test tls_handshake::test_tls_record_clientkeyexchange ... ok
test tls_handshake::test_tls_record_clienthello ... ok
test tls_handshake::test_tls_record_changecipherspec ... ok
test tls_handshake::test_tls_record_invalid_messagelength ... ok
test tls_handshake::test_tls_record_encryptedhandshake ... ok
test tls_handshake::test_tls_record_invalid_messagelength2 ... ok
test tls_handshake::test_tls_record_invalid_recordlength ... ok
test tls_handshake::test_tls_record_invalid_recordlength2 ... ok
test tls_handshake::test_tls_record_serverdone ... ok
test tls_handshake::test_tls_record_serverhello ... ok
test tls_handshake::test_tls_record_serverkeyexchange ... ok

test result: ok. 15 passed; 0 failed; 0 ignored; 0 measured
```


# Fuzzing

En utilisant [https://github.com/frewsxcv/afl.rs](afl-rs)

```
Fuzzers alive : 5
Total run time : 19 days, 13 hours
Total execs : 4054 million
Cumulative speed : 11987 execs/sec
Pending paths : 0 faves, 0 total
Pending per fuzzer : 0 faves, 0 total (on average)
Crashes found : 0 locally unique
```

# Job's done

* Page du projet: [Rusticata](https://github.com/rusticata)
* Parseurs publiés:
* TLS
* IPsec (IKEv2 uniquement)
* NTP
* DER
* SNMP (très partiel)
* Par Victor Julien: DNS, Quic, NFSv3 (TCP)
* Parseurs écrits mais non publiés:
* PE
* SSH
* HTTP2

# Feedback

* Parseurs **sûrs**
* et **réutilisables**
* Écriture de parseurs vraiment plus rapide
* Plus de segfaults !

<p />

* Plus gros impact: humain
* Langage **strict**, qui force les vérifications
* Lisibilité de Rust pas terrible (discutable)
* Plus une marque de manque d'habitude
* Macros difficiles à debugger
* Lifetimes parfois difficiles

# Projets

Autres projets de parseurs en Rust

* [syslog-ng regex parser](https://syslog-ng.org/filling-the-parse-method/)
* [FLV plugin for VLC](https://github.com/Geal/rust-vlc-demux)
* [Librsvg >= 2.41.0](https://mail.gnome.org/archives/desktop-devel-list/2017-January/msg00001.html)
* [gstreamer](https://coaxion.net/blog/2016/11/writing-gstreamer-elements-in-rust-part-3-parsing-data-from-untrusted-sources-like-its-2016/)


