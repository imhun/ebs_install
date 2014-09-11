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
		srcPath=InputBox("请输入上线代码目录，相对目录为ebs_prod:")	
		'srcPath="C:\Users\zjrcu\Desktop\70代码\ebs_prod"	
		if Not fso.FolderExists(srcPath) Then
			MsgBox "Source Directory not exist:<" & srcPath & ">"
			wscript.quit
	 	end if
	 	
		histPath=InputBox("请输入历史版本目录，相对目录为ebs_prod:")	
		'histPath="C:\Users\zjrcu\Desktop\TEST\70代码\ebs_prod"
		if Not fso.FolderExists(histPath) Then
			MsgBox "History Directory not exist:<" & histPath & ">"
			wscript.quit
	 	end if
	 	
	 	onlineDateStr=InputBox("请输入上线日期，格式:YYYY-MM-DD:")	
		'onlineDateStr="2014-07-25"
		if onlineDateStr="" Then
			MsgBox "上线日期必须输入!"
			wscript.quit
	 	end if
	 	
	 	onlineDate=cdate(onlineDateStr)
	 	onlineDateS=CStr(Year(onlineDate))&Right("0"&Month(onlineDate),2)&Right("0"&Day(onlineDate),2)
	 	
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
		sysUser=sysName & "_ZB"
		taskUser="徐永桂"
		
		onlineDir=currdir & "\" & onlineDateS & "\"
		createDir onlineDir
		
		Set fsql= fso.opentextfile(onlineDir +  "\" & onlineDateS & "_" & sysUser & ".sql", 2, True) 
		
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
				    objdir=obj("objDir") 
				    langdir=obj("langDir")  
				    apphost="ebs1"
				    appuser="ebsapp"
				    
				   	histfile=replace(obj("path"),srcPath,histPath) 	
				    relateDir= objdir & langdir
				    newRelDir=relateDir
				    newfile=fname
				    if fext="pls" or fext="plb" or fext="sql" or fext="ldt" or fext="fmb" or fext="pll" or fext="rtf" or fext="rdf" or fext="wft" then
				    	stype=otype
						taskType=""
						taskDesc=""
				   		taskNewFlag=1
						taskCmd="NULL"
						taskParam=objname
						
						if fext="fmb" or fext="pll" or fext="rdf" then	
							apphost="ebs1|ebs2|ebs3|ebs4"
							appuser="ebsapp|ebsapp|ebsapp|ebsapp"
						end if
						
						if  fext="pls" or fext="plb" or fext="sql" then
							taskCmd=fname
							if  okey="TABLE"  or okey="TABLE_INDEX" or okey="TABLE_INSERT" or okey="TABLE_UPDATE" or okey="TABLE_DELETE" then
								taskType="ORA_SQL_TMP"
								newRelDir="table"  & langdir
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
						elseif fext="fmb" or fext="pll" then
							if lang="" then
								lang="US"
							end if
							taskType= okey & "_" & lang & "_FORM"
							taskParam=okey & "|" & oname
						elseif fext="wft" then
							taskType= "_" & lang & "_WFLOAD"
							taskParam= oname
						elseif fext="rtf" then
							taskType= okey & "_" & lang & "_RPTLOAD"
							taskParam=okey & "|" & objname
						elseif fext="rdf" then
							taskType=   "REPORTS_" & lang & "_SQLFILE"
							taskCmd=fname
							taskParam=""
					  	end if
					  	
					  	if taskType <>"" then 
							taskSeq=taskSeq+1
							if okey="TABLE_INDEX" then
								taskDesc="索引:" & objname
								taskParam=""
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
							
							cpFile fso,obj("path"),destPath & "\" & onlineDateS & "\" & sysName & "\" &  obj("eventName") & "\new_version\" &  newRelDir & fname
						  	if fso.fileexists(histfile) then
						  		cpFile fso,histfile,destPath & "\" & onlineDateS & "\" & sysName & "\" &  obj("eventName") & "\old_version\" &  newRelDir & fname
						  		taskNewFlag=0
						  	end if
						  	
							if taskNewFlag=1 then
								taskDesc="创建" & taskDesc
							elseif taskNewFlag=0 then
								taskDesc="修改" & taskDesc
							end if
							
							if taskNewFlag=0 and okey="TABLE" then
								taskSeq=taskseq-1
							else
								sqlStr="insert into dwmm.online_metadata(ONLINE_DT,BATCH_NO,JOB_OWNER,EVENT_ID,EVENT_NM,PRE_EVENT_ID,IS_NEW_JOB_F,EVENT_SEQ," &_
											 "JOB_TP,SYS_TP,JOB_DSC,JOB_CMD,IS_ND_ROLLBK_F,PARAMS,RUN_USER,JOB_STS,RUN_HOST,RELATE_EVENT_ROLL) values " & chr(10) &_
											"('" & onlineDateStr & "',1,'" & taskUser& "    ','" & sysUser & "_" & obj("eventNo") & "','" & obj("eventName") & "',''," & taskNewFlag &_
											 "," & taskSeq & ",'" & taskType & "','" & sysName & "','" & taskDesc & "','" & taskCmd & "',1,'" & taskParam & "','" & appuser & "','WAITING','" & apphost & "',0);"
								
								lineStr= "1," & taskUser & "," & sysUser & "_0" & obj("eventNo") & "," & obj("eventName") & ",," & taskNewFlag &_
								 "," & taskSeq & "," & taskType & "," & sysName & "," & taskDesc & "," & taskCmd & ",1," & taskParam & ",," & appuser & ",WAITING,,,," & apphost & ",0"
								 'Msgbox linestr
								 'Wscript.quit
								fsql.writeline sqlStr
								flist.writeline lineStr
						 	end if
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
		fsql.close
		MsgBox "OK! " & cnt & " items.", vbOKOnly, "allfiles"
End Sub

' Run
Call dotest()