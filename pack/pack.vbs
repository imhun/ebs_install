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
		srcPath=InputBox("Please input source path:")	
		'srcPath="C:\Users\zjrcu\Desktop\70代码\ebs_prod"	
		if Not fso.FolderExists(srcPath) Then
			MsgBox "Source Directory not exist:<" & srcPath & ">"
			wscript.quit
	 	end if
	 	
		histPath=InputBox("Please input history path:")	
		'histPath="C:\MyProject\ZJRCU\GAS_EBS_BRANCH\GAS_TST_EBS\70代码\ebs_prod"
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
				    oname=obj("name")
				    fext=obj("ext")
				    fname=obj("fname")
				    
				   	histfile=replace(obj("path"),srcPath,histPath) 	
				    relateDir=  obj("objDir") & "\" &  obj("lang")  & "\" &  obj("fname")  
				    
				    if fext="pls" or fext="plb" or fext="sql" then
				    	stype=otype
						taskType=""
						taskDesc=""
				   		taskNewFlag=1
						taskCmd=fname
						taskParam=oname
						if  left(okey,5)="TABLE" or okey="DB_TEMP" then
							taskType="ORA_SQL_TMP"
						else
							taskType="ORA_" & okey
					  	end if
					  	
					  	if taskType <>"" then 
							taskSeq=taskSeq+1
							if okey="TABLE_INDEX" then
								taskDesc="索引:" & oname
							elseif okey="TABLE_ALTER" or okey ="TABLE" then
								taskDesc="表:" & oname
							elseif left(okey,6)="TABLE_" then
								taskDesc="执行sql脚本:" &  fname
							else
								taskDesc=okey & ":" & oname
							end if
							
							cpFile fso,obj("path"),destPath & "\" & sysName & "\" &  obj("eventName") & "\new_version\" &  relateDir
						  	if fso.fileexists(histfile) then
						  		cpFile fso,histfile,destPath & "\" & sysName & "\" &  obj("eventName") & "\old_version\" &  relateDir
						  		taskNewFlag=0
						  	end if
						  	
							if taskNewFlag=1 then
								taskDesc="创建" & taskDesc
							elseif taskNewFlag=0 then
								taskDesc="修改" & taskDesc
							end if
							
							lineStr= "1,徐永桂," & sysName & "_ZB_0" & obj("eventNo") & "," & obj("eventName") & ",," & taskNewFlag &_
							 "," & taskSeq & "," & taskType & "," & sysName & "," & taskDesc & "," & taskCmd & ",1," & taskParam & ",,ebsapp,WAITING,,,,ebs1,0"
							 'Msgbox linestr
							 'Wscript.quit
							flist.writeline lineStr
						end if
					else
						stype=okey
					end if	
				  		
				  	cpFile fso,obj("path"),destPath & "\install\code\" & obj("instType") & "\" & relateDir
				  	if fso.fileexists(histfile) then
				  		cpFile fso,histfile,destPath & "\bak\code\" & obj("instType") & "\" &  relateDir
				  	end if
					
					fObjlist.writeline stype & "|" & oname
		    	next
		  	next
	  	next
	
		
		fobjlist.Close    ' 关闭输出文件.
		flist.close
		MsgBox "OK! " & cnt & " items.", vbOKOnly, "allfiles"
End Sub

' Run
Call dotest()