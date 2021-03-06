Option Explicit

'--- 定数
' [WdSaveFormat Enumeration (Word)](https://msdn.microsoft.com/en-us/library/office/ff839952.aspx)
Const wdFormatDocument = 0
Const wdFormatDOSText = 4
Const wdFormatDOSTextLineBreaks = 5
Const wdFormatEncodedText = 7
Const wdFormatFilteredHTML = 10
Const wdFormatFlatXML = 19
Const wdFormatFlatXMLMacroEnabled = 20
Const wdFormatFlatXMLTemplate = 21
Const wdFormatFlatXMLTemplateMacroEnabled = 22
Const wdFormatOpenDocumentText = 23
Const wdFormatHTML = 8
Const wdFormatRTF = 6
Const wdFormatStrictOpenXMLDocument = 24
Const wdFormatTemplate = 1
Const wdFormatText = 2
Const wdFormatTextLineBreaks = 3
Const wdFormatUnicodeText = 7
Const wdFormatWebArchive = 9
Const wdFormatXML = 11
Const wdFormatDocument97 = 0
Const wdFormatDocumentDefault = 16
Const wdFormatPDF = 17
Const wdFormatTemplate97 = 1
Const wdFormatXMLDocument = 12
Const wdFormatXMLDocumentMacroEnabled = 13
Const wdFormatXMLTemplate = 14
Const wdFormatXMLTemplateMacroEnabled = 15
Const wdFormatXPS = 18

' [WdStoryType Enumeration (Word)](https://msdn.microsoft.com/en-us/library/office/ff844990.aspx)
Const wdCommentsStory = 4
Const wdEndnoteContinuationNoticeStory = 17
Const wdEndnoteContinuationSeparatorStory = 16
Const wdEndnoteSeparatorStory = 15
Const wdEndnotesStory = 3
Const wdEvenPagesFooterStory = 8
Const wdEvenPagesHeaderStory = 6
Const wdFirstPageFooterStory = 11
Const wdFirstPageHeaderStory = 10
Const wdFootnoteContinuationNoticeStory = 14
Const wdFootnoteContinuationSeparatorStory = 13
Const wdFootnoteSeparatorStory = 12
Const wdFootnotesStory = 2
Const wdMainTextStory = 1
Const wdPrimaryFooterStory = 9
Const wdPrimaryHeaderStory = 7
Const wdTextFrameStory = 5


'--- リンク画像→埋め込み画像変換
' ※ Word 2007 以降用
'   [Word2007 not displaying embedded images.](https://social.msdn.microsoft.com/Forums/vstudio/en-US/d3d5fa18-2d25-41bd-977f-18d58a4b51b8/word2007-not-displaying-embedded-images?forum=vsto)
'   [word VBA for save picture in document - Stack Overflow](http://stackoverflow.com/questions/23194907/word-vba-for-save-picture-in-document)
' ※ Word 2003 以前は以下を参照
'   [Importing an HTML document into Word via COM Automation and dealing with Image Embedding (revisited) - Rick Strahl's Web Log](https://weblog.west-wind.com/posts/2004/Dec/14/Importing-an-HTML-document-into-Word-via-COM-Automation-and-dealing-with-Image-Embedding-revisited)
Sub EmbedImages( objDocument )
    Dim objShape
    
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


'--- Evernote の「作成日」／「更新日」→日時情報作成
Function DateTimeInfo( objTimeStamp )
    Dim objDateTimeInfo
    Dim strYear, strMonth, strDate, strHours, strMinutes, strSeconds
    
    Set objDateTimeInfo = WScript.CreateObject( "Scripting.Dictionary" )
    
    strYear = PadLeft( objTimeStamp.submatches( 0 ), 4, "0" )
    strMonth = PadLeft( objTimeStamp.submatches( 1 ), 2, "0" )
    strDate = PadLeft( objTimeStamp.submatches( 2 ), 2, "0" )
    strHours = PadLeft( objTimeStamp.submatches( 3 ), 2, "0" )
    strMinutes = PadLeft( objTimeStamp.submatches( 4 ), 2, "0" )
    strSeconds = "00"
    
    objDateTimeInfo.Add "Year", strYear
    objDateTimeInfo.Add "Month", strMonth
    objDateTimeInfo.Add "Date", strDate
    objDateTimeInfo.Add "Hours", strHours
    objDateTimeInfo.Add "Minutes", strMinutes
    objDateTimeInfo.Add "Seconds", strSeconds
    
    objDateTimeInfo.Add "TimeStamp", strYear & "/" & strMonth & "/" & strDate & " " & strHours & ":" & strMinutes & ":" & strSeconds
    objDateTimeInfo.Add "FilePrefix", strYear & strMonth & strDate & "_" & strHours & strMinutes & "-"
    
    Set DateTimeInfo = objDateTimeInfo
End Function


'--- タイムスタンプ取得
' ※ Evernote よりエクスポートする際にオプションで「作成日」や「更新日」を指定した場合、これを取得してタイムスタンプとする
Function EvernoteTimeStamp( objDocument, strHeader )
    Dim TimeStampKinds : TimeStampKinds = Array( "Created", "Modified" )
    Dim objTimeStampInfo
    Dim objRegTimestamp
    Dim strDocumentText
    Dim objTimeStampMatches, objTimeStamp
    Dim intIndex
    
    Set objTimeStampInfo = WScript.CreateObject( "Scripting.Dictionary" )
    
    If IsNull( strHeader ) Then
        strHeader = "(?:作成|更新)日"
    End If
    
    Set objRegTimestamp = new RegExp
    With objRegTimestamp
        .pattern = strHeader & "[^\d]*(\d+)/(\d+)/(\d+)[^\d]*(\d+):(\d+)"
        .IgnoreCase = True
        .Global = True
        .Multiline = False
    End With
    
    'strDocumentText = objDocument.Range( 0, objDocument.Bookmarks( "\EndOfDoc" ).End ).Text
    strDocumentText = objDocument.StoryRanges( wdMainTextStory ).Text
    
    Set objTimeStampMatches = objRegTimestamp.Execute( strDocumentText )
    
    ' [TODO] 厳密には「作成日」→"Created"、「更新日」→"Modified"の対応になっていない
    '        最初にヒットしたものを作成日として決め打ちし、ひとつしか出てこなかった場合は更新日も同じ日時に設定している。
    intIndex = 0
    For Each objTimeStamp In objTimeStampMatches
        objTimeStampInfo.Add TimeStampKinds( intIndex ), DateTimeInfo( objTimeStamp )
        intIndex = intIndex + 1
        If UBound( TimeStampKinds ) < intIndex Then
            Exit For
        End If
    Next
    
    If intIndex = 0 Then
        For intIndex = 0 To UBound( TimeStampKinds )
            objTimeStampInfo.Add TimeStampKinds( intIndex ), Null
        Next
    Else
        For intIndex = intIndex To UBound( TimeStampKinds )
            objTimeStampInfo.Add TimeStampKinds( intIndex ), objTimeStampInfo( TimeStampKinds( intIndex - 1 ) )
        Next
    End If
    
    Set EvernoteTimeStamp = objTimeStampInfo
End Function


'--- HTML → Word 変換
Function HtmlToWord( strInFile )
    HtmlToWord = 0
    
    Dim objFSO, objShellApp
    Dim strFileExt
    Dim objDocument
    Dim objTimeStamp
    Dim objTimeStampCreated, objTimeStampModified
    Dim strTimestamp
    Dim strOutFile
    Dim objOutFile
    
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
    Set objTimeStamp = EvernoteTimeStamp( objDocument, Null )
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
    
    ' ファイル更新日設定
    ' [TODO] ファイル作成日の変更方法は不明（変更できない？）
    Set objOutFile = objShellApp.NameSpace( objFSO.GetParentFolderName( strOutFile ) ).ParseName( objFSO.GetFilename( strOutFile ) )
    
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
Dim intConvertCounter : intConvertCounter = 0
Dim objFSO, objWordApp
Dim strInFile
Dim objFolder, objFile

Set objFSO = CreateObject( "Scripting.FileSystemObject" )
Set objWordApp = CreateObject( "Word.Application" )
objWordApp.Application.Visible = False


' ドラッグ＆ドロップされたファイル中、拡張子が html のものを docx に変換
For Each strInFile In WScript.Arguments
    If objFSO.FileExists( strInFile ) Then
        ' HTML → Word 変換
        intConvertCounter = intConvertCounter + HtmlToWord( strInFile )
    ElseIf objFSO.FolderExists( strInFile ) Then
        Set objFolder = objFSO.GetFolder( strInFile )
        
        For Each objFile In objFolder.Files
            ' HTML → Word 変換
            intConvertCounter = intConvertCounter + HtmlToWord( objFile.Path )
        Next
    End If
Next

objWordApp.Quit

MsgBox "変換完了: " & intConvertCounter & " ファイル"
