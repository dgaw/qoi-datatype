/*
** Datatype functions header
*/

extern void DebugLog(char *str);
extern Class *__saveds __asm ObtainPicClass(register __a6 struct ClassBase *cb);
extern Class *initClass(struct ClassBase *cb);
extern ULONG __saveds __asm Dispatch(register __a0 Class *cl,
                                     register __a2 Object *o,
                                     register __a1 Msg msg);
