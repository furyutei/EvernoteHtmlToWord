'--- リンク画像→埋め込み画像変換
' ※ Word 2007 以降用
'   [Word2007 not displaying embedded images.](https://social.msdn.microsoft.com/Forums/vstudio/en-US/d3d5fa18-2d25-41bd-977f-18d58a4b51b8/word2007-not-displaying-embedded-images?forum=vsto)
'   [word VBA for save picture in document - Stack Overflow](http://stackoverflow.com/questions/23194907/word-vba-for-save-picture-in-document)
' ※ Word 2003 以前は以下を参照
'   [Importing an HTML document into Word via COM Automation and dealing with Image Embedding (revisited) - Rick Strahl's Web Log](https://weblog.west-wind.com/posts/2004/Dec/14/Importing-an-HTML-document-into-Word-via-COM-Automation-and-dealing-with-Image-Embedding-revisited)

Sub EmbedImages( objDocument )
    For Each objShape In objDocument.InlineShapes
        If Not objShape.LinkFormat Is Nothing Then
            objShape.LinkFormat.SavePictureWithDocument = True
            objShape.LinkFormat.BreakLink
        End If
    Next
End Sub


'--- 指定文字でパディング
'  参考：[まいてっくぶろぐ - 【VBS】文字列が指定桁数に満たない場合、0詰めする関数](http://hkzumi.blog60.fc2.com/blog-entry-222.html)
Function PadLeft( strTarget, intLength , chPad )
   Do While ( Len( strTarget ) < intLength )
       strTarget = chPad & strTarget
   Loop
   PadLeft = Right( strTarget, intLength )
End Function


'--- 
Function DateTimeInfo( objTimeStamp )
    Set DateTimeInfo = WScript.CreateObject( "Scripting.Dictionary" )
    
    strYear = PadLeft( objTimeStamp.submatches( 0 ), 4, "0" )
    strMonth = PadLeft( objTimeStamp.submatches( 1 ), 2, "0" )
    strDate = PadLeft( objTimeStamp.submatches( 2 ), 2, "0" )
    strHours = PadLeft( objTimeStamp.submatches( 3 ), 2, "0" )
    strMinutes = PadLeft( objTimeStamp.submatches( 4 ), 2, "0" )
    strSeconds = "00"
    
    DateTimeInfo.Add "Year", strYear
    DateTimeInfo.Add "Month", strMonth
    DateTimeInfo.Add "Date", strDate
    DateTimeInfo.Add "Hours", strHours
    DateTimeInfo.Add "Minutes", strMinues
    DateTimeInfo.Add "Seconds", strSeconds
    
    DateTImeInfo.Add "TimeStamp", strYear & "/" & strMonth & "/" & strDate & " " & strHours & ":" & strMinutes & ":" & strSeconds
    DateTimeInfo.Add "FilePrefix", strYear & strMonth & strDate & "_" & strHours & strMinutes & "-"
End Function


'--- タイムスタンプ取得
' ※ Evernote よりエクスポートする際にオプションで「作成日」や「更新日」を指定した場合、これを取得してタイムスタンプとする
Function EvernoteTimeStamp( objDocument, strHeader )
    TimeStampKinds = Array( "Created", "Modified" )
    Set objTimeStampInfo = WScript.CreateObject( "Scripting.Dictionary" )
    
    Set objRegTimestamp = new RegExp
    With objRegTimestamp
        .pattern = strHeader & "[^\d]*(\d+)/(\d+)/(\d+)[^\d]*(\d+):(\d+)"
        .IgnoreCase = True
        .Global = True
        .Multiline = False
    End With
    
    With objDocument
        strText = .Range( 0, .Bookmarks( "\EndOfDoc" ).End ).Text
    End With
    
    Set objTimeStampMatches = objRegTimestamp.Execute( strText )
    
    ' [TODO] 最初にヒットしたものを作成日として決め打ちし、ひとつしか出てこなかった場合は更新日も同じ日時に設定している
    cntLoop = 0
    For Each objTimeStamp In objTimeStampMatches
        objTimeStampInfo.Add TimeStampKinds( cntLoop ), DateTimeInfo( objTimeStamp )
        cntLoop = cntLoop + 1
        If UBound( TimeStampKinds ) < cntLoop Then
            Exit For
        End If
    Next
    
    If cntLoop = 0 Then
        For cntLoop = 0 To UBound( TimeStampKinds )
            objTimeStampInfo.Add TimeStampKinds( cntLoop ), Null
        Next
    Else
        For cntLoop = cntLoop To UBound( TimeStampKinds )
            objTimeStampInfo.Add TimeStampKinds( cntLoop ), objTimeStampInfo( TimeStampKinds( cntLoop - 1 ) )
        Next
    End If
    
    Set EvernoteTimeStamp = objTimeStampInfo
End Function


'--- HTML → Word 変換
Function HtmlToWord( strInFile )
    HtmlToWord = 0
    
    Set objFSO = CreateObject( "Scripting.FileSystemObject" )
    Set objShellApp = CreateObject( "Shell.Application" )
    
    strFileExt = LCase( objFSO.GetExtensionName( strInFile ) )
    
    If strFileExt <> "html" And strFileExt <> "htm" Then
        Exit Function ' HTML のみ対象
    End If
    
    If Left( objFSO.GetBaseName( strInFile ), 2 ) = "~$" Then
        Exit Function ' バックアップファイルは無視
    End If
    
    ' HTML を Word で読み込み
    Set objDocument = objWordApp.Documents.Open( strInFile )
    
    ' リンク画像→埋め込み画像変換
    EmbedImages objDocument
    
    ' 出力ファイル名作成
    Set objTimeStamp = EvernoteTimeStamp( objDocument, "(?:作成|更新)日" )
    If IsNull( objTimeStamp( "Created" ) ) Then
        objTimeStampCreated = Null
    Else
        Set objTimeStampCreated = objTimeStamp( "Created" )
    End If
    
    If IsNull( objTimeStampCreated ) Then
        strTimestamp = ""
    Else
        strTimeStamp = objTimeStampCreated( "FilePrefix" )
    End If
    
    strOutFile = objFSO.BuildPath( objFSO.GetParentFolderName( strInFile ), strTimeStamp & objFSO.GetBaseName( strInFile ) & ".docx" )
    
    ' Word ファイル出力
    objDocument.SaveAs strOutFile, wdFormatXMLDocument
    
    objDocument.Close
    
    Set objOutFile = objShellApp.NameSpace( objFSO.GetParentFolderName( strOutFile ) ).ParseName( objFSO.GetFilename( strOutFile ) )
    
    ' ファイル更新日設定
    ' [TODO] ファイル作成日の変更方法は不明（変更できない？）
    If IsNull( objTimeStamp( "Modified" ) ) Then
        objTimeStampModified = Null
    Else
        Set objTimeStampModified = objTimeStamp( "Modified" )
    End If
    If Not IsNull( objTimeStampModified ) Then
        If IsDate( objTimeStampModified( "TimeStamp" ) ) Then
            objOutFile.ModifyDate = objTimeStampModified( "TimeStamp" )
        End If
    End If
    
    HtmlToWord = 1
End Function


'=== メイン処理
Set objFSO = CreateObject( "Scripting.FileSystemObject" )
Set objWordApp = CreateObject( "Word.Application" )
objWordApp.Application.Visible = False

cntConverted = 0

' ドラッグ＆ドロップされたファイル中、拡張子が html のものを docx に変換
For Each strInFile In WScript.Arguments
    If objFSO.FileExists( strInFile ) Then
        ' HTML → Word 変換
        cntConverted = cntConverted + HtmlToWord( strInFile )
    ElseIf objFSO.FolderExists( strInFile ) Then
        Set objFolder = objFSO.GetFolder( strInFile )
        
        For Each objFile In objFolder.Files
            ' HTML → Word 変換
            cntConverted = cntConverted + HtmlToWord( objFile.Path )
        Next
    End If
Next

objWordApp.Quit

MsgBox "変換完了: " & cntConverted & " ファイル"
