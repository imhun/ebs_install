Dim filedata
Dim langcfg
Dim defLang
Dim extcfg
Dim definecfg

Function readConfig(fso,cfgFile)
	Set f = fso.OpenTextFile(cfgFile, 1)
	strJson = f.ReadAll
	f.Close
	Set f=Nothing
	
	Set oJson=New aspJSON	
	oJson.loadJSON(strJson)
	
	set readConfig=oJson.data
end function

sub getTypeCfg(fso) 
	set data=readConfig(fso,"..\lib\type.cfg")
	set langcfg=data("lang")
	set extcfg=data("ext")
	set definecfg=data("define")
	
	for each key in langcfg
		set lang=langcfg(key)
		if lang("type")="default" then
			deflang=lang("code")
		end if
	next
end sub

'获取文件属性
Function getObjType(fso,fobj,byref okey,byref oname,byref olang,byref seq,byref instType,byref objDir)
	sbase = ""
	otype=""
	okey=""
	owner=""
	oname=""
	olang=""
	seq=""
	instType=""
	objDir=""
	fpath=fobj.path
	path=fobj.ParentFolder
    sext = Lcase(GetFileExtAndBaseName(fobj.name, sbase)) 

    for each key in langcfg 
    	set lang=langcfg(key)
	    if instr(fpath,"\" & lang("code") & "\")>0 then
	    	olang=lang("code")
	    end if
  	next
  	
  	if extcfg.exists(sext) then
  		
  		set cfg=extcfg(sext)
  		sdefine=cfg("define")
  		keytype=cfg("keytype")
  		if cfg.exists("keys") then
  			strline=""
  			keyval=""
  			set filekeys=cfg("keys")
			Set f = fso.OpenTextFile(fpath, 1,true,0)
			Do Until f.AtEndOfStream
				strline=replace(Ucase(trim(f.ReadLine)),"""","")
				if strline<>"" then
					'Msgbox "strline:" & strline
					if keytype="sql" then
						for each idx in filekeys
							set filekey=filekeys(idx)
							set keya=filekey("keya")
							for each i in keya 
								keyval=keya(i)
								keylen=len(keyval)
		  						'Msgbox "for keya=>type:" & filekey("type") & chr(10) & "key:" & keyval & chr(10) & "left:" & keylen & "," & left(strline,keylen) & chr(10) 
								if left(strline,keylen)=keyval then
									otype=filekey("type")
									oarr=split(trim(replace(strline,keyval,"")) ," ")
									oname=oarr(0)
									exit do
								end if
							next
						next	
				 	elseif keytype="fndload" then
			  			if olang="" and instr(strline,filekeys(0))> 0 then				
							oa=split(strline," ")
							olang=oa(2)
						elseif otype="" and instr(strline,filekeys(1))>0 then
							oa=split(strline," ")
							otype=oa(1)
						elseif otype<>"" and instr(strline,filekeys(2) & " " & otype)>0 then
							oa=split(strline," ")
							oname=oa(2)
							if UBound(oa)>=3 then
								owner=oa(3)
							end if 
							exit do
						end if
				 	elseif keytype="xdf" then
				 		
						if owner="next_line" then
							owner=strline
						elseif oname="next_line" then
							oname=strline
						elseif otype="next_line" then
							otype=strline
							oname=owner & "." & oname
							exit do
						end if
						
			  			if owner="" and instr(strline,Ucase(filekeys(0)))> 0 then				
							owner="next_line"
						elseif oname="" and instr(strline,Ucase(filekeys(1)))>0 then
							oname="next_line"
						elseif otype="" and instr(strline,Ucase(filekeys(2)))>0 then
							otype="next_line"
						end if
						
					end if
				end if
			loop
			f.close
		else
			otype=keytype
  			oname=Ucase(sbase)
  		end if
  		
    	'Msgbox fpath & chr(10)  & "=>type:" & otype & ",name:" & oname & ",owner:" & owner & ",lang:" & olang
    	if otype<>"" then
	    	set typeobj=definecfg(sdefine)(otype)
	    	
	    	if typeobj.exists("app_pre") then
				if typeobj("app_pre")="Y" then
					oname=oname & "." & owner
				else
					oname=owner & "." & oname
				end if
			end if
			
	    	if typeobj.exists("key") then
	    		okey=typeobj("key")
	    	else
	    		okey=otype
	    	end if
	    	
	    	objdir=typeobj("dir")
    		seq=typeobj("seq")
			instType=cfg("inst")
				
			if oname<>"" and instr(oname,".")=0 then
				oname="CUX." & oname
			end if
			
			if cfg.exists("pathkey")  then
				if instr(path,"\" & cfg("pathkey") & "\")>0 then
					objDir=mid(path,instr(path,"\" & cfg("pathkey") & "\")+1)
				end if
			end if
				
  			if cfg.exists("multilang") and cfg("multilang")="Y" then
  				if olang="" then
  					olang=deflang
  				end if
  			else
  				olang=""
  			end if
    	end if
  
  	end if
    'Msgbox fpath & chr(10) & "result=>type:" & otype & ",key:" & okey & ",seq:" & seq & ",name:" & oname & ",lang:" & olang & ",inst:" & instType & ",dir:" & objdir
    'Wscript.quit
	getObjType=otype
end function

Function fileobj(fso,fobj)
    otype=""
    sbase = ""
    fext = GetFileExtAndBaseName(fobj.name, sbase)    ' À©Õ¹Ãû.
	otype=getObjType(fso,fobj,okey,oname,olang,seq,instType,objDir)
	set obj=Collection()
	obj("key")= seq & "_" & okey
	obj("typekey")= okey
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


Function dirobj(fso, ByVal sPath,eventNo,eventName)
    rt = 0
    Set currentFolder = Nothing
    'MsgBox sPath
    
    On Error Resume Next
    Set currentFolder = fso.GetFolder(sPath)
    On Error Goto 0
    
    if eventNo=0 then
    	getTypeCfg(fso)
    end if
    
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
            sfull = f.Path
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
				    '	setFileAttr fso,destFile,32
				    'end if			    
				    'Msgbox destfile
				  	cpFile fso,obj("path"),destFile
			  	end if		  	
	    	next
	  	next
  	next
  	procFiles=filecnt
end function
