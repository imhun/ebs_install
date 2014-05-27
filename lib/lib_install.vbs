Dim filedata
Dim langobj
'获取安装文件类型及其他属性
Function getObjType(fso,fobj,byref oname,byref olang,byref seq,byref instType,byref objDir)
	sbase = ""
	oname=""
	olang=""
	seq=""
	instType=""
	objDir=""
	fpath=fobj.path
	path=fobj.ParentFolder
    sext = Lcase(GetFileExtAndBaseName(fobj.name, sbase)) 
    cnt=0
    
    if instr(fpath,"\ZHS\")>0 then
    	olang="ZHS"
    elseif instr(fpath,"\US\")>0 then
    	olang="US"
    end if
    
	if sext="fmb" then
		otype="FORM"
		oname="CUX." & Ucase(sbase)
		seq=110
		instType="app"
		objDir="forms"
		if olang="" then
			olang="ZHS"
		end if
	elseif sext="pll" then
		otype= "RESOURCE"
		oname="CUX." &Ucase(sbase)
		seq=100
		instType="app"
		objDir="resource"
	elseif sext="rdf" then
		otype="REPORT"
		oname="CUX." & Ucase(sbase)
		seq=120
		instType="app"
		objDir="reports"
		if olang="" then
			olang="ZHS"
		end if
	elseif sext="rtf" then
		otype="XDO_TEMPLATE"
		oname="CUX." & Ucase(sbase)
		seq=130
		instType="db"
		objDir="xdoload\template"
		if olang="" then
			olang="ZHS"
		end if
	elseif instr(fpath,"\oaf\")>0 and (sext="class" or sext ="xml") then
		otype="OAF"
		objDir=mid(path,instr(path,"\oaf\")+1)
		seq=140
		instType="app"
	elseif sext="pls" or sext="plb" or sext="sql" or sext="ldt" or sext="wft" or sext="xml" then
   		Set f = fso.OpenTextFile(fpath, 1,true,0)
		Do Until f.AtEndOfStream
			strline=replace(Ucase(trim(f.ReadLine)),"""","")
			if sext ="sql" or sext="pls" or sext="plb" then		
				if instr(strline,"CREATE TABLE")>0 then
					otype="TABLE"
					stype="CREATE TABLE"	
					seq=10
					instType="db"
					objDir="table"
				elseif instr(strline,"ALTER TABLE")>0 then					
					otype="TABLE_ALTER"
					stype="ALTER TABLE"
					seq=10
					instType="db"
					objDir="table"
				elseif instr(strline,"CREATE GLOBAL TEMPORARY TABLE")>0 then
					otype="TABLE"
					stype="CREATE GLOBAL TEMPORARY TABLE"
					seq=10
					instType="db"
					objDir="table"
				elseif instr(strline,"CREATE OR REPLACE SYNONYM")>0 then
					otype="SYNONYM"
					stype="CREATE OR REPLACE SYNONYM"
					seq=20
					instType="db"
					objDir="synonym"
				elseif instr(strline,"CREATE SEQUENCE")>0 then
					otype="SEQUENCE"
					stype="CREATE SEQUENCE"
					seq=30
					instType="db"
					objDir="sequence"
				elseif instr(strline,"CREATE INDEX")>0 then
					otype="TABLE_INDEX"
					stype="CREATE INDEX"
					seq=35
					instType="db"
					objDir="sql"
				elseif instr(strline,"INSERT INTO")>0 then
					otype="TABLE_DATA"
					stype="INSERT INTO"
					seq=35
					instType="db"
					objDir="sql"
				elseif instr(strline,"UPDATE")>0  then					
					otype="TABLE_DATA"
					stype="UPDATE"
					seq=35
					instType="db"
					objDir="sql"
				elseif instr(strline,"DELETE FROM")>0 then					
					otype="TABLE_DATA"
					stype="DELETE FROM"
					seq=35
					instType="db"
					objDir="sql"
				elseif instr(strline,"CREATE OR REPLACE PACKAGE BODY")>0 then
					otype="PACKAGE_BODY"
					stype="CREATE OR REPLACE PACKAGE BODY"
					seq=60
					instType="db"
					objDir="package"
				elseif instr(strline,"CREATE OR REPLACE PACKAGE")>0 then
					otype="PACKAGE_SPEC"
					stype="CREATE OR REPLACE PACKAGE"
					seq=40
					instType="db"
					objDir="package"
				elseif instr(strline,"CREATE OR REPLACE VIEW")>0 then
					otype="VIEW"
					stype="CREATE OR REPLACE VIEW"
					seq=50
					instType="db"
					objDir="view"
				elseif instr(strline,"CREATE OR REPLACE FORCE VIEW")>0 then
					otype="VIEW"
					stype="CREATE OR REPLACE FORCE VIEW"	
					seq=50
					instType="db"
					objDir="view"
				elseif instr(strline,"CREATE OR REPLACE TRIGGER")>0 then
					otype="TRIGGER"
					stype="CREATE OR REPLACE TRIGGER"
					seq=70
					instType="db"
					objDir="trigger"
				else
					otype="DB_TEMP"
					seq=75
					instType="db"
					objDir="sql"
				end if
				if otype<>"" and otype<>"DB_TEMP" then
					oarr=split(trim(replace(strline,stype,"")) ," ")
					oname=oarr(0)
					exit do
				end if
			elseif sext="ldt" then
				if olang="" and instr(strline,"LANGUAGE =")> 0 then				
					oa=split(strline," ")
					olang=oa(2)
				elseif otype="" and instr(strline,"DEFINE ")>0 then
					oa=split(strline," ")
					otype=oa(1)
					
					seq=80
					instType="db"
				elseif otype<>"" and instr(strline,"BEGIN "&otype) then
					oa=split(strline," ")
					oname=oa(2)
					if UBound(oa)>=3 then
						oname=oa(3) & "." &oname
					end if 
					if otype="PROGRAM" then
						otype="REQUEST"
					elseif otype="FND_LOOKUP_TYPE" then
						otype="LOOKUP"
					elseif otype="DESC_FLEX" then
						otype="DESCFLEX"
					elseif otype="KEY_FLEX" then
						otype="KEYFLEX"
					elseif otype="REQUEST_GROUP" then
						otype="REQUESTGROUP"
					elseif otype="REQ_SET" then
						otype="REQUESTSET"
					elseif otype="VALUE_SET" then
						otype="VALUESET"
					elseif otype="XDO_DS_DEFINITIONS" then
						otype="XDO_DATADEFINE"
					elseif otype="FND_RESPONSIBILITY" then
						otype="RESPONSIBILITY"
					elseif otype="FND_FORM_CUSTOM_RULES" then
						otype="CUSTOMRULE"
					elseif otype="FND_NEW_MESSAGES" then
						otype="MESSAGE"
					elseif otype="FND_APPLICATION" then
						otype="FND_APP"
					end if
					objDir="fndload\" & lcase(otype)
					exit do
				end if
			elseif sext="wft" then
				if instr(strline,"BEGIN ITEM_TYPE ")>0 then
					oa=split(strline," ")
					otype="WORKFLOW"
					oname="CUX." & oa(2)
					seq=90
					instType="db"
					objDir=lcase(otype)
					if olang="" then
						olang="ZHS"
					end if
					exit do
				end if
			end if		
		loop 
		f.close
	end if
	
	
	getObjType=otype
end function

Function fileobj(fso,fobj)
    otype=""
    sbase = ""
    fext = GetFileExtAndBaseName(fobj.name, sbase)    ' 扩展名.
	otype=getObjType(fso,fobj,oname,olang,seq,instType,objDir)
	set obj=Collection()
	obj("key")= seq & "_" & otype
	obj("type")=otype
	obj("name")=oname
	obj("lang")=olang
	if olang<>"" then
		obj("langDir")="\" & olang & "\"
	else
		obj("langDir")="\"
	end if
	obj("seq")=seq
	obj("instType")=instType
	obj("objDir")=objDir
	obj("ext")=fext
	obj("path")=fobj.path
	obj("fname")=fobj.name
	 	
	set fileobj=obj
end function

' 遍历该目录及子目录.
'
' Result: 目录和文件的总数.
' fileOut: 输出文件，用于输出遍历结果.
' fso: FileSystemObject对象.
' sPath: 目录.
Function dirobj(fso, ByVal sPath,eventNo,eventName)
    rt = 0
    Set currentFolder = Nothing
    'MsgBox sPath
    
    On Error Resume Next
    Set currentFolder = fso.GetFolder(sPath)
    On Error Goto 0
    
    If Not (currentFolder is Nothing) Then  	
		eventID=0
		eventNm=""
        ' Folders
        For Each subFolder in currentFolder.SubFolders
                
     		if eventNo=0 then
     			eventID=eventID+1
     			eventNm=subFolder.name
     			set filedata(eventID)=Collection()
     	    else
     	  		eventID=eventNo
     	  		eventNm=eventName
          	end if
         
            rt = rt + dirobj( fso, subFolder.Path,eventID,eventNm)        	
        Next
        
       if eventNo=0 then
     		set filedata(eventNo)=Collection()
       		eventName=currentFolder.name
       end if
        ' Files
       For Each f in currentFolder.Files            
            sfull = f.Path    ' 全限定名.
            rt = rt + 1
            
            set obj= fileobj(fso,f)
		  	obj("eventNo")=eventNo
		  	obj("eventName")=eventName
            okey=obj("key")
            idx=0
            if filedata(eventNo).exists(okey) then
            	idx=filedata(eventNo)(okey).count+1
            	set filedata(eventNo)(okey)(idx)=obj
            else
            	idx=1
            	set objs=Collection()
            	set objs(idx)=obj
            	set filedata(eventNo)(okey)=objs
            end if          
        Next
    End If
    
    dirobj = rt
End Function

function procFiles(fso,srcpath,destPath)
    
	filecnt=dirObj(fso,srcpath,0,"")
	filecnt=0
	for each row in filedata
		set eventObj=filedata(row)
	    keys=QuickSort(eventObj.keys)
	    
	    for each key in keys
	     	for each idx in eventObj(key).keys
	    		set obj=eventObj(key)(idx)			   	
			   	if obj("type")<>"" then
			   		filecnt=filecnt+1
				    relateDir=  obj("objDir") & obj("langDir")  &  obj("fname")  	
				    destFile=destPath & "\code\" & obj("instType") & "\" & relateDir
				    'if fso.fileexists(destFile) then
				    '	clearFileAttr fso,destFile,1
				    'end if			    
				  	cpFile fso,obj("path"),destFile
			  	end if		  	
	    	next
	  	next
  	next
  	procFiles=filecnt
end function