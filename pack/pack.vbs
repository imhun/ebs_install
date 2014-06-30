' Include函数，通过FSO组件读取外部函数文件内容
' 通过ExecuteGlobal载入
Sub include(file)
    Dim fso, f, strcon
    Set fso = CreateObject("Scripting.FileSystemObject")
    Set f = fso.OpenTextFile(file, 1)
    strcon = f.ReadAll
    f.Close
    ExecuteGlobal strcon
    Set fso=Nothing
    Set f=Nothing
End Sub

Dim srcPath
Dim destPath
Dim histPath

' 测试
Sub dotest

		'包含文件处理库
		include "..\lib\lib.vbs"
		include "..\lib\lib_install.vbs"
		include "..\lib\aspjson.vbs"
		
		Set fso = CreateObject("Scripting.FileSystemObject")
    	currDir= GetCurrentFolderFullPath(fso,Wscript.ScriptFullName) 
		'srcPath=InputBox("Please input source path:")	
		srcPath="C:\Users\zjrcu\Desktop\70代码\ebs_prod"	
		if Not fso.FolderExists(srcPath) Then
			MsgBox "Source Directory not exist:<" & srcPath & ">"
			wscript.quit
	 	end if
	 	
		'histPath=InputBox("Please input history path:")	
		histPath="C:\MyProject\ZJRCU\GAS_EBS_BRANCH\GAS_TST_EBS\70代码\ebs_prod"
		if Not fso.FolderExists(histPath) Then
			MsgBox "History Directory not exist:<" & histPath & ">"
			wscript.quit
	 	end if
	 	
		destPath = currDir
		
	 	strDir=destPath & "\install"
	 	if fso.folderexists(strDir) then  	
			fso.deletefolder strDir,True
		end if
		
		strDir=destPath & "\GAS"
	 	if fso.folderexists(strDir) then  	
			fso.deletefolder strDir,True
		end if
		
	    if fso.folderExists(histPath) then
			strDir=destPath & "\bak"
		 	if fso.folderexists(strDir) then  	
				fso.deletefolder strDir,True
			end if	
		end if
	  
		Set filedata = Collection()
    	cnt=dirobj(fso,srcPath,0,"")
    	
		Set fobjlist = fso.opentextfile(destPath+"\objlist.cfg", 2, True)    ' 打开输出文件. ForWriting, TristateTrue.
		Set flist= fso.opentextfile(currdir+"\list.csv", 2, True) 
		
		sysName="RCUGAS"
		taskUser="徐永桂"
		for each row in filedata
			set eventObj=filedata(row)
		    keys=QuickSort(eventObj.keys)
		    taskSeq=0
		    for each key in keys
		     	for each idx in eventObj(key).keys
		    		set obj=eventObj(key)(idx)
		    		'Msgbox "key:" & key & ",type:" & obj("type") & ",typekey:" & obj("typekey")
		    		stype=""
				    otype=obj("type")
				    okey=obj("typekey")
				    objname=obj("objname")
				    oname=obj("name")
				    fext=obj("ext")
				    fname=obj("fname")
				    lang=obj("lang")
				    
				   	histfile=replace(obj("path"),srcPath,histPath) 	
				    relateDir=  obj("objDir") & obj("langDir")  
				    newfile=fname
				    if fext="pls" or fext="plb" or fext="sql" or fext="ldt" or fext="fmb" or fext="rtf" or fext="rdf" or fext="wft" then
				    	stype=otype
						taskType=""
						taskDesc=""
				   		taskNewFlag=1
						taskCmd="NULL"
						taskParam=objname
						
						if  fext="pls" or fext="plb" or fext="sql" then
							taskCmd=fname
							if  okey="TABLE"  or okey="TABLE_INSERT" or okey="TABLE_UPDATE" or okey="TABLE_DELETE" then
								taskType="ORA_SQL_TMP"
							elseif okey="TABLE_ALTER" then
								taskType="ORA_TABLE_ONLY"
							else
								taskType="ORA_" & okey
						  	end if
						elseif fext="ldt" then
							newfile=oname & "." & fext
							taskType=okey & "_" & lang & "_FNDLOAD"
							taskParam=okey & "|" & objname
							if okey="REQUEST" then
								taskCmd="P_VSET_DOWNLOAD_CHILDREN=N"
							elseif okey="PROFILE" then
								taskCmd="PROFILE_VALUES=N"
							end if
						elseif fext="fmb" then
							taskType= "*_" & lang & "_FORM"
						elseif fext="pll" then
							taskType= "*_RESOURCE"
						elseif fext="wft" then
							taskType= "*_" & lang & "_WFLOAD"
						elseif fext="rtf" then
							taskType= "*_" & lang & "_RPTLOAD"
					  	end if
					  	
					  	if taskType <>"" then 
							taskSeq=taskSeq+1
							if okey="TABLE_INDEX" then
								taskDesc="索引:" & objname
							elseif okey ="TABLE" then
								taskDesc="表:" & objname
							elseif okey="TABLE_ALTER" then
								taskNewFlag=0
								taskDesc="表:" & objname
							elseif okey="TABLE_INSERT" or okey="TABLE_UPDATE" or okey="TABLE_DELETE" then
								taskDesc="执行sql脚本:" &  newfile
								taskParam=""
							else
								taskDesc=okey & ":" & objname
							end if
							
							cpFile fso,obj("path"),destPath & "\" & sysName & "\" &  obj("eventName") & "\new_version\" &  relateDir & newfile
						  	if fso.fileexists(histfile) then
						  		cpFile fso,histfile,destPath & "\" & sysName & "\" &  obj("eventName") & "\old_version\" &  relateDir & newfile
						  		taskNewFlag=0
						  	end if
						  	
							if taskNewFlag=1 then
								taskDesc="创建" & taskDesc
							elseif taskNewFlag=0 then
								taskDesc="修改" & taskDesc
							end if
							
							lineStr= "1," & taskUser & "," & sysName & "_ZB_0" & obj("eventNo") & "," & obj("eventName") & ",," & taskNewFlag &_
							 "," & taskSeq & "," & taskType & "," & sysName & "," & taskDesc & "," & taskCmd & ",1," & taskParam & ",,ebsapp,WAITING,,,,ebs1,0"
							 'Msgbox linestr
							 'Wscript.quit
							flist.writeline lineStr
						end if
					else
						stype=okey
					end if	
					
				  	cpFile fso,obj("path"),destPath & "\install\code\" & obj("instType") & "\" & relateDir &   fname
				  	if fso.fileexists(histfile) then
				  		cpFile fso,histfile,destPath & "\bak\code\" & obj("instType") & "\" &  relateDir & fname
				  	end if
					
					fObjlist.writeline stype & "|" & objname
		    	next
		  	next
	  	next
	
		
		fobjlist.Close    ' 关闭输出文件.
		flist.close
		MsgBox "OK! " & cnt & " items.", vbOKOnly, "allfiles"
End Sub

' Run
Call dotest()