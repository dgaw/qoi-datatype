/*
** Datatype functions
*/

#define __USE_SYSBASE

#ifndef EXEC_TYPES_H
#include <exec/types.h>
#endif /* EXEC_TYPES_H */

#ifndef EXEC_MEMORY_H
#include <exec/memory.h>
#endif /* EXEC_MEMORY_H */

#ifndef GRAPHICS_GFXBASE_H
#include <graphics/gfxbase.h>
#endif /* GRAPHICS_GFXBASE_H */

#ifndef GRAPHICS_VIEW_H
#include <graphics/view.h>
#endif /* GRAPHICS_VIEW_H */

#include <datatypes/pictureclass.h>
#include <intuition/icclass.h>

#include <cybergraphx/cybergraphics.h> /* V43 Picture DT */

#include <proto/datatypes.h>
#include <proto/dos.h>
#include <proto/exec.h>
#include <proto/graphics.h>
#include <proto/intuition.h>
#include <proto/utility.h>

#include <clib/alib_protos.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include "libfuncs.h"
#include <class/classbase.h>

#include <qoi/qoi.h>
#include "qoicustom.h"

#define LibVer(x) (((struct Library *)x)->lib_Version)

#ifdef DEBUGLOG
void DebugLog(char *str) {
  BPTR fh;
  fh = Open("T:qoi-debug.log", MODE_READWRITE);
  if (fh) {
    Seek(fh, 0, OFFSET_END);
    FPuts(fh, str);
    Close(fh);
  }
}
#else
void DebugLog(char *str) {}
#endif

Class *__saveds __asm ObtainPicClass(register __a6 struct ClassBase *cb) {
  return (cb->cb_Class);
}

extern char __aligned ExLibName[];

Class *initClass(struct ClassBase *cb) {
  Class *cl;

  if (cl = MakeClass(&ExLibName[0], PICTUREDTCLASS, NULL, NULL, 0L)) {
    cl->cl_Dispatcher.h_Entry = (HOOKFUNC)Dispatch;
    cl->cl_UserData = (ULONG)cb;
    AddClass(cl);
  }

  return (cl);
}

ULONG __saveds __stdargs DTS_GetBestModeID(ULONG width, ULONG height,
                                           ULONG depth) {
  ULONG mode_id;

  mode_id = BestModeID(BIDTAG_NominalWidth, width, BIDTAG_NominalHeight, height,
                       BIDTAG_DesiredWidth, width, BIDTAG_DesiredHeight, height,
                       BIDTAG_Depth, depth, TAG_END);

  if (mode_id == INVALID_ID) {
    /* Uses OverScan values for checking. */
    /* Assumes an ECS-System.             */

    if ((width > 724) && (depth < 3))
      mode_id = SUPER_KEY;
    else if ((width > 362) && (depth < 5))
      mode_id = HIRES_KEY;
    else
      mode_id = LORES_KEY;

    if (!ModeNotAvailable(mode_id | PAL_MONITOR_ID)) /* for PAL  Systems */
    {
      if (height > 283)
        mode_id |= LACE;

      mode_id |= PAL_MONITOR_ID;
    } else {
      if (!ModeNotAvailable(mode_id | NTSC_MONITOR_ID)) /* for NTSC Systems */
      {
        if (height > 241)
          mode_id |= LACE;

        mode_id |= NTSC_MONITOR_ID;
      }
    }
  }

  return (mode_id);
}

/* Read the whole file into a buffer.
   Returns a pointer to the buffer.
   Puts the size of the file into file_size.
   Make sure to free the buffer when done!
*/
APTR ReadFile(STRPTR file_name, ULONG *file_size) {
  BPTR fh;
  struct stat file_stat;
  APTR file_buffer;

  // Read the file into a buffer
  if (lstat(file_name, &file_stat) == -1) {
    DebugLog("Can't stat file\n");
    SetIoErr(ERROR_OBJECT_NOT_FOUND);
    return NULL;
  }

  *file_size = file_stat.st_size;

  fh = Open(file_name, MODE_OLDFILE);
  if (!fh) {
    DebugLog("Can't open file\n");
    SetIoErr(ERROR_OBJECT_NOT_FOUND);
    return NULL;
  }

  file_buffer = AllocVec(*file_size, MEMF_PUBLIC);
  if (!file_buffer) {
    DebugLog("Can't allocate file buffer\n");
    Close(fh);
    SetIoErr(ERROR_NO_FREE_STORE);
    return NULL;
  }

  if (FRead(fh, file_buffer, *file_size, 1) != 1) {
    DebugLog("Can't read whole file\n");
    Close(fh);
    return NULL;
  }

  Close(fh);
  return file_buffer;
}

ULONG GetGfxData(Class *cl, Object *o, struct TagItem *attrs) {
  extern struct Library *SuperClassBase;
  struct BitMapHeader *bmhd;
  UBYTE *file_name;
  APTR file_buffer;
  ULONG file_size;
  ULONG source_type;
  qoi_desc desc;
  qoi_decoding_state decoding_state;
  void *pixel_buffer;
  int pixel_buffer_size;              // in bytes
  const int pixel_buffer_height = 20; // in pixels
  const int channels_to_decode = 3;
  int lines_to_write;
  int i;
  ULONG mem_start, mem_before_free, mem_after_free;
  char debug_line[70];

  // We can't handle clipboard, ram or other access modes
  source_type = (ULONG)GetTagData(DTA_SourceType, DTST_FILE, attrs);
  if (source_type != DTST_FILE) {
    SetIoErr(ERROR_OBJECT_WRONG_TYPE);
    return FALSE;
  }

  file_name = (UBYTE *)GetTagData(DTA_Name, NULL, attrs);
  GetDTAttrs(o,PDTA_BitMapHeader, &bmhd, TAG_DONE);

  mem_start = AvailMem(MEMF_ANY);

  // Read the whole file
  // TODO, maybe: read the file in chunks to reduce memory usage.
  file_buffer = ReadFile(file_name, &file_size);
  if (!file_buffer) {
    DebugLog("Can't read file into a buffer\n");
    return FALSE;
  }

  // Decode the header into `desc`
  if (!qoi_decode_header(file_buffer, file_size, &desc)) {
    DebugLog("Can't qoi_decode_header\n");
    return FALSE;
  }

  bmhd->bmh_Width = (bmhd->bmh_PageWidth = desc.width);
  bmhd->bmh_Height = (bmhd->bmh_PageHeight = desc.height);
  bmhd->bmh_Depth = 24;

  SetDTAttrs(o, NULL, NULL, DTA_ObjName, file_name, DTA_NominalHoriz, bmhd->bmh_Width,
             DTA_NominalVert, bmhd->bmh_Height, PDTA_SourceMode, PMODE_V43,
             PDTA_ModeID,
             DTS_GetBestModeID(bmhd->bmh_Width, bmhd->bmh_Height, 8), TAG_DONE);

  pixel_buffer_size = desc.width * pixel_buffer_height * channels_to_decode;
  pixel_buffer = AllocVec(pixel_buffer_size, MEMF_PUBLIC);
  if (!qoi_init_decoding_state(&decoding_state)) {
    DebugLog("Can't qoi_init_decoding_state\n");
    return FALSE;
  }

  // Decode the file buffer into the pixel_buffer 10 lines at a time
  // writing each batch to picture.datatype
  for (i = 0; i < desc.height; i += pixel_buffer_height) {
    if (!qoi_decode_some(file_buffer, file_size, channels_to_decode,
                         &decoding_state, pixel_buffer, pixel_buffer_size)) {
      DebugLog("Can't qoi_decode_some\n");
      return FALSE;
    }

    if (i + pixel_buffer_height > desc.height) {
      lines_to_write = desc.height % pixel_buffer_height;
    } else {
      lines_to_write = pixel_buffer_height;
    }

    DoSuperMethod(cl, o, PDTM_WRITEPIXELARRAY, pixel_buffer, RECTFMT_RGB,
                  desc.width * channels_to_decode, 0, i, desc.width,
                  lines_to_write);
  }

  mem_before_free = AvailMem(MEMF_ANY);
  sprintf(debug_line, "Used bytes before free: %d\n",
          mem_start - mem_before_free);
  DebugLog(debug_line);

  FreeVec(pixel_buffer);
  FreeVec(file_buffer);

  mem_after_free = AvailMem(MEMF_ANY);
  sprintf(debug_line, "Used bytes after free: %d\n", mem_start - mem_after_free);
  DebugLog(debug_line);

  return TRUE;
}

ULONG __saveds __asm Dispatch(register __a0 Class *cl, register __a2 Object *o,
                              register __a1 Msg msg) {
  ULONG retval;

  switch (msg->MethodID) {
  case OM_NEW: {
    if (retval = DoSuperMethodA(cl, o, msg)) {
      if (!GetGfxData(cl, (Object *)retval,
                      ((struct opSet *)msg)->ops_AttrList)) {
        CoerceMethod(cl, (Object *)retval, OM_DISPOSE);
        return NULL;
      }
    }
    break;
  }
  default: {
    retval = (ULONG)DoSuperMethodA(cl, o, msg);
    break;
  }
  }

  return (retval);
}
