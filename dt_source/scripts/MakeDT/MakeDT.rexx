/*
**	MakeDT.rexx - ARexx script to create DataType recogs
**	$VER: MakeDT.rexx 1.3 (17.11.96)
**	Written by Michal Letowski
**
**	1.0 (20.12.94) - initial version, not released
**	1.1 (22.11.94) - 1st public version
**	1.2 (29.1.96)  - 2nd public version
**		+ now can write FVER chunk
**		! fixed bug in tags conversion
**	1.3 (17.11.96) - 3rd public version
**		! fixed numerous bugs
*/

SIGNAL ON BREAK_C

PARSE ARG descrFile outFile .

IF descrFile='' THEN
DO
	SAY 'Usage: MakeDT <DescriptionFile> [<DestDataType>]'
	EXIT 20
END

IF ~OPEN(FH,descrFile,'R') THEN
	CALL Error('Unable to open description file' descrFile,20)

Header.=''																	/* Init header */
Code.=''																		/* Init code */
Code.Exists=0
Tools.=''																		/* Init tool */
DO I=1 TO 5
	Tools.I.Exists=0
END
Tags.=''																		/* Init tags */
Tags.Count=1

DO LineNum=1 WHILE ~EOF(FH)
	Line=READLN(FH)
	IF Line='' THEN
		LEAVE
	Line=STRIP(Line,'L')											/* Remove leading spaces */
	IF SUBSTR(Line,1,1)='#' THEN							/* Skip comment */
		ITERATE
	PARSE VAR Line Comm '=' Value
	UPPER Comm
	SELECT
		WHEN ABBREV('FILENAME',Comm) THEN
			IF outFile='' THEN
				outFile=Value
		WHEN ABBREV('DTNAME',Comm) THEN		CALL ParseDTName(Value,LineNum)
		WHEN ABBREV('ID',Comm) THEN				CALL ParseID(Value,LineNum)
		WHEN ABBREV('VERSION',Comm) THEN	CALL ParseVersion(Value,LineNum)
		WHEN ABBREV('RECOG',Comm) THEN		CALL ParseRecog(Value,LineNum)
		WHEN ABBREV('FLAGS',Comm) THEN		CALL ParseFlags(Value,LineNum)
		WHEN ABBREV('CODE',Comm) THEN			CALL ParseCode(Value,LineNum)
		WHEN ABBREV('TOOL',Comm) THEN			CALL ParseTool(Value,LineNum)
		WHEN ABBREV('TAG',Comm) THEN			CALL ParseTag(Value,LineNum)
		OTHERWISE
			CALL Error('Error in line' LineNum ': Unknown command',10)
	END
END
CALL CLOSE(FH)
CALL Check(outFile)
CALL Consolidate
CALL Write
CALL WriteFile(outFile)

EXIT


/*
**	MakeDT procedures
*/
ParseDTName:	PROCEDURE EXPOSE Header.
	PARSE ARG value,line
	PARSE VAR value Header.Name ',' Header.BaseName
	IF Header.Name='' | Header.BaseName='' THEN
		CALL Error('Error in line' line ': <Name> and <BaseName> must not be null',10)
RETURN

ParseVersion:	PROCEDURE EXPOSE Header.
	PARSE ARG value,line
	PARSE VAR value Header.Version '.' Header.Revision
	IF ~DATATYPE(Header.Version,'W') | ~DATATYPE(Header.Revision,'W') THEN
		CALL Error('Error in line' line ': <Version> or <Revision> not numeric',10)
RETURN

ParseID:	PROCEDURE EXPOSE Header.
	PARSE ARG value,line
	PARSE VAR value Header.GroupID ',' Header.ID
	IF Header.GroupID='' | Header.ID='' THEN
		CALL Error('Error in line' line ': <GroupID> and <FileID> must not be null',10)
	IF FIND('syst text docu soun inst musi pict anim movi',Header.GroupID)=0 THEN
		CALL Error('Warning in line' line ': Unknown <GroupID>',5)
	IF LENGTH(Header.GroupID)>5 | LENGTH(Header.ID)>4 THEN
		CALL Error('Error in line' line ': <GroupID> and <FileID> may be up to 4 chars',10)
RETURN

ParseRecog:	PROCEDURE EXPOSE Header.
	PARSE ARG value,line
	PARSE VAR value Header.Pattern ',' Header.Mask
	Header.Mask=CDecode(Header.Mask,line)
	Header.MaskLen=LENGTH(Header.Mask)%2
RETURN

ParseFlags:	PROCEDURE EXPOSE Header.
	PARSE ARG value,line
	PARSE UPPER VAR value Type ',' Case ',' Pri
	SELECT
		WHEN ABBREV('BINARY',Type) THEN	Header.Flags=0
		WHEN ABBREV('ASCII',Type) THEN	Header.Flags=1
		WHEN ABBREV('IFF',Type) THEN		Header.Flags=2
		WHEN ABBREV('OTHER',Type) THEN	Header.Flags=3
		OTHERWISE
			CALL Error('Error in line' line ': Type must be <Binary>, <ASCII>, <IFF> or <Other>',10)
	END
	IF Case='Y' THEN
		Header.Flags=Header.Flags+16
	SELECT
		WHEN Pri='' THEN
			Header.Priority=0
		WHEN DATATYPE(Pri,'W') THEN
			IF Pri>=0 & Pri<=65535 THEN
				Header.Priority=Pri
			ELSE
				CALL Error('Error in line' line ': <Priority> must be in 0..65535 range',10)
		OTHERWISE
			CALL Error('Error in line' line ': <Priority> not numeric',10)
	END
RETURN

ParseCode:	PROCEDURE EXPOSE Code.
	PARSE ARG value,line
	Code.Exists=0
	IF value='' THEN
		RETURN
	Code.Exists=OPEN(CodeFH,value,'R')
	If ~Code.Exists THEN
		CALL Error('Error in line' line ': <Code> file does not exist',10)
	Code.Code=READCH(CodeFH,65536)
	CALL CLOSE(CodeFH)
	Code.Exists=1
RETURN

ParseTool:	PROCEDURE EXPOSE Tools.
	PARSE ARG value,line
	IF value='' THEN
		RETURN
	PARSE VAR value Type ',' Name ',' Kind
	UPPER Type
	UPPER Kind
	SELECT
		WHEN ABBREV('INFO',Type) THEN		ToolNumber=1
		WHEN ABBREV('BROWSE',Type) THEN	ToolNumber=2
		WHEN ABBREV('EDIT',Type) THEN		ToolNumber=3
		WHEN ABBREV('PRINT',Type) THEN	ToolNumber=4
		WHEN ABBREV('MAIL',Type) THEN		ToolNumber=5
		OTHERWISE
			CALL Error('Error in line' line ': Unknown tool type',10)
	END
	SELECT
		WHEN ABBREV('CLI',Kind) THEN				Tools.ToolNumber.Flags=1
		WHEN ABBREV('WORKBENCH',Kind) THEN	Tools.ToolNumber.Flags=2
		WHEN ABBREV('AREXX',Kind) THEN			Tools.ToolNumber.Flags=3
		OTHERWISE
			CALL Error('Error in line' line ': Unknown kind of tool',10)
	END
	IF Name='' THEN
		CALL Error('Error in line' line ': <ToolName> must not be null',10)
	Tools.ToolNumber.Program=Name
	Tools.ToolNumber.Exists=1
RETURN

ParseTag:	PROCEDURE EXPOSE Tags.
	PARSE ARG value,line
	IF value='' THEN
		RETURN
	Counter=Tags.Count
	PARSE UPPER VAR value TagName ',' TagValue
	IF TagName='' | TagValue='' THEN
		CALL Error('Error in line' line ': <TagName> or <TagValue> empty',10)
	IF SUBSTR(TagName,1,1)='$' THEN DO
		IF ~DATATYPE(SUBSTR(TagName,2),'X') THEN
			CALL Error('Error in line' line ': <TagName> not numeric',10)
		ELSE
			Tags.Counter.Name=X2C(SUBSTR(TagName,2))
	END
	ELSE DO
		IF ~DATATYPE(TagName,'W') THEN
			CALL Error('Error in line' line ': <TagName> not numeric',10)
		ELSE
			Tags.Counter.Name=D2C(TagName)
	END
	IF SUBSTR(TagValue,1,1)='$' THEN DO
		IF ~DATATYPE(SUBSTR(TagValue,2),'X') THEN
			CALL'Error in line' line ': <TagValue> not numeric',10)
		ELSE
			Tags.Counter.Val=X2C(SUBSTR(TagValue,2))
	END
	ELSE DO
		IF ~DATATYPE(TagValue,'W') THEN
			CALL Error('Error in line' line ': <TagValue> not numeric',10)
		ELSE
			Tags.Counter.Val=D2C(TagValue)
	END
	Tags.Count=Tags.Count+1
RETURN

CDecode: PROCEDURE
	PARSE ARG encoded,line
	Decoded=''
	DO I=1 TO LENGTH(encoded)
		IF SUBSTR(encoded,I,1)='\' THEN DO
			I=I+1
			SELECT
				WHEN SUBSTR(encoded,I,1)='?' THEN
					Decoded=Decoded||'FFFF'X
				WHEN SUBSTR(encoded,I,1)='\' THEN
					Decoded=Decoded||'00'X||'\'
				WHEN SUBSTR(encoded,I,1)='$' THEN DO
					Hex=SUBSTR(encoded,I+1,2)
					IF DATATYPE(Hex,'X') THEN DO
						Decoded=Decoded||'00'X||X2C(Hex)
						I=I+2
					END
					ELSE
						CALL Error('Error in line' line ": Hexadecimal number expected after '$'",10)
				END
				OTHERWISE
					CALL Error('Error in line' line ': Unknown escape character',10)
			END
		END
		ELSE
			Decoded=Decoded||'00'X||SUBSTR(encoded,I,1)
	END
RETURN Decoded

Check:	PROCEDURE EXPOSE Header.
	PARSE ARG file
	IF file='' THEN
		CALL Error('Error: <DestFile> must not be null',10)
	IF Header.Name='' | Header.BaseName='' THEN
		CALL Error('Error: <Name> and <BaseName> must not be null',10)
	IF Header.GroupID='' | Header.ID='' THEN
		CALL Error('Error: <GroupID> and <FileID> must not be null',10)
	IF Header.Pattern='' & Header.Mask='' THEN
		CALL Error('Warning: Both <Pattern> and <Mask> are null',5)
RETURN

Consolidate:	PROCEDURE EXPOSE Header.
SAY Header.Version'.'Header.revision
	/* Consolidate version string */
	Header.VerString='$VER:'
	Header.VerString=Header.VerString Header.Name
	Header.VerString=Header.VerString Header.Version'.'Header.Revision
	Header.VerString=Header.VerString '('MakeDate()')'
RETURN


Write:	PROCEDURE EXPOSE Header. Code. Tools. Tags.
	TAB='09'X
	SAY 'Version:   '||Header.VerString
	SAY 'Name:      '||Header.Name
	SAY 'Base name: '||Header.BaseName
	SAY 'Group ID:  '||Header.GroupID
	SAY 'ID:        '||Header.ID
	SAY 'Pattern:   '||Header.Pattern
	SAY 'Mask len:  '||Header.MaskLen
	SAY 'Mask:      '||Header.Mask
	SAY 'Flags:     '||Header.Flags
	SAY 'Priority:  '||Header.Priority
	SAY
	IF Code.Name~='' THEN
	DO
		SAY 'Function name: '||Code.Name
		SAY
	END
	DO I=1 TO 5
		IF Tools.I.Exists THEN
		DO
			SAY 'Tool name:   ' Tools.I.Program
			SAY 'Type of tool:' I
			SAY 'Kind of tool:' Tools.I.Flags
			SAY
		END
	END
	DO I=1 TO Tags.Count-1
		SAY 'Tag name:' C2X(Tags.I.Name) 'Tag value:' C2D(Tags.I.Val)
	END
RETURN

WriteFile:	PROCEDURE EXPOSE Header. Code. Tools. Tags.
	PARSE ARG file
	Header.Name=Header.Name||'0'X
	Header.BaseName=Header.BaseName||'0'X
	Header.Pattern=Header.Pattern||'0'X
	Header.VerString=Header.VerString||'0'X
	DO I=1 TO 5
		Tools.I.Program=Tools.I.Program||'0'X
	END
	NameLen=Len(FilePart(file)'0'X)
	VerLen=Len(Header.VerString)
	HeaderLen=Len(Header.Name)+Len(Header.BaseName)+Len(Header.Pattern)
	HeaderLen=HeaderLen+32+Header.MaskLen*2
	CodeLen=Len(Code.Code)
	DO I=1 TO 5
		ToolLen.I=8+Len(Tools.I.Program)
	END
	TagsLen=(Tags.Count-1)*8
	TagsExist=Tags.Count>1
	TotalLen=4
	IF Header.VerString~='0'X THEN
		TotalLen=TotalLen+8+VerLen
	TotalLen=TotalLen+8+NameLen
	TotalLen=TotalLen+8+HeaderLen
	TotalLen=TotalLen+(8+CodeLen)*Code.Exists
	DO I=1 TO 5
		TotalLen=TotalLen+(8+ToolLen.I)*Tools.I.Exists
	END
	TotalLen=TotalLen+(8+TagsLen)*TagsExist
	IF ~OPEN(FH,file,'W') THEN
		CALL Error('Unable to open output file' file,20)

	/* Save header */
	CALL WRITECH(FH,'FORM')
	CALL WRITECH(FH,Long(TotalLen))
	CALL WRITECH(FH,'DTYP')

	/* Save FVER chunk */
	IF Header.VerString~='0'X THEN
	DO
		CALL WRITECH(FH,'FVER')
		CALL WRITECH(FH,Long(VerLen))
		CALL WRITECH(FH,Pad(Header.VerString))
	END

	/* Save NAME chunk */
	CALL WRITECH(FH,'NAME')
	CALL WRITECH(FH,Long(NameLen))
	CALL WRITECH(FH,Pad(FilePart(file)'0'X))

	/* Save DTHD chunk */
	CALL WRITECH(FH,'DTHD')
	CALL WRITECH(FH,Long(HeaderLen))
	CALL WRITECH(FH,Long(32+Header.MaskLen*2))
	CALL WRITECH(FH,Long(32+Header.MaskLen*2+Len(Header.Name)))
	CALL WRITECH(FH,Long(32+Header.MaskLen*2+Len(Header.Name)+Len(Header.BaseName)))
	CALL WRITECH(FH,Long(32))
	CALL WRITECH(FH,PadR(Header.GroupID))
	CALL WRITECH(FH,PadR(Header.ID))
	CALL WRITECH(FH,Word(Header.MaskLen))
	CALL WRITECH(FH,Word(0))
	CALL WRITECH(FH,Word(Header.Flags))
	CALL WRITECH(FH,Word(Header.Priority))
	CALL WRITECH(FH,Header.Mask)
	CALL WRITECH(FH,Pad(Header.Name))
	CALL WRITECH(FH,Pad(Header.BaseName))
	CALL WRITECH(FH,Pad(Header.Pattern))

	/* Save DTCD chunk */
	IF Code.Exists THEN
	DO
		CALL WRITECH(FH,'DTCD')
		CALL WRITECH(FH,Long(CodeLen))
		CALL WRITECH(FH,Pad(Code.Code))
	END

	/* Save DTTL chunk */
	DO I=1 TO 5	
		IF Tools.I.Exists THEN
		DO
			CALL WRITECH(FH,'DTTL')
			CALL WRITECH(FH,Long(ToolLen.I))
			CALL WRITECH(FH,Word(I))
			CALL WRITECH(FH,Word(Tools.I.Flags))
			CALL WRITECH(FH,Long(8))
			CALL WRITECH(FH,Pad(Tools.I.Program))
		END
	END

	/* Save DTTG chunk */
	IF Tags.Count>1 THEN DO
		CALL WRITECH(FH,'DTTG')
		CALL WRITECH(FH,Long(TagsLen))
		DO I=1 To Tags.Count-1
			CALL WRITECH(FH,RIGHT(Tags.I.Name,4,'0'X)||RIGHT(Tags.I.Val,4,'0'X))
		END
	END
	
	SAY 'DataType written!'
RETURN

Error:	PROCEDURE
	PARSE ARG string,code
	SAY string
	IF code>5 THEN
		EXIT code
	ELSE
		RETURN


/*
**	Utility procedures
*/
Len:	PROCEDURE
	PARSE ARG string
	L=LENGTH(string)
	IF L//2=0 THEN
		RETURN L
	ELSE
		RETURN L+1

Pad:	PROCEDURE
	PARSE ARG string
	L=LENGTH(string)
	IF L//2=0 THEN
		RETURN string
	ELSE
		RETURN string||'00'X

PadR:	PROCEDURE
	PARSE ARG string
RETURN LEFT(string,4,'0'X)

Word:	PROCEDURE
	PARSE ARG num .
RETURN RIGHT(D2C(num),2,'0'X)

Long:	PROCEDURE
	PARSE ARG num .
RETURN RIGHT(D2C(num),4,'0'X)

FilePart:	PROCEDURE
	PARSE ARG path
	SepPos=Max(LastPos('/',path),LastPos(':',path))+1
	PARSE VAR path PathPart =SepPos FilePart
RETURN FilePart

MakeDate:	PROCEDURE
	PARSE VALUE Date('E') WITH day '/' month '/' year
	IF LEFT(day,1)='0' 	THEN	PARSE VAR day '0' day
	IF LEFT(month,1)='0' THEN	PARSE VAR month '0' month
RETURN day'.'month'.'year
	

BREAK_C:
	SAY 'DataType not written!'
	EXIT
