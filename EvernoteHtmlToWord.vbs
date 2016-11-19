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


'--- タイムスタンプ取得
' ※ Evernote よりエクスポートする際にオプションで「作成日」や「更新日」を指定した場合、これを取得してタイムスタンプとする
Function EvernoteTimeStamp( objDocument, strHeader )
    Set objRE = new RegExp
    With objRE
        .pattern = strHeader & "[^\d]*(\d+)/(\d+)/(\d+)[^\d]*(\d+):(\d+)"
        .IgnoreCase = True
        .Global = True
        .Multiline = False
    End With
    
    With objDocument
        strText = .Range( 0, .Bookmarks( "\EndOfDoc" ).End ).Text
    End With
    
    Set strMatches = objRE.Execute( strText )
    
    If 0 < strMatches.Count Then
        Set strMatch = strMatches( 0 )
        EvernoteTimeStamp = strMatch.submatches( 0 ) & strMatch.submatches( 1 ) & strMatch.submatches( 2 ) & "_"
        EvernoteTimeStamp = EvernoteTimeStamp & PadLeft( strMatch.submatches( 3 ), 2, "0" ) & PadLeft( strMatch.submatches( 4 ), 2, "0" )
    Else
        EvernoteTimeStamp = ""
    End If
End Function


'--- HTML → Word 変換
Function HtmlToWord( strInFile )
    HtmlToWord = 0
    
    strFileExt = LCase( objFSO.GetExtensionName( strInFile ) )
    
    If strFileExt <> "html" And strFileExt <> "htm" Then
        Exit Function
    End If
    
    ' HTML を Word で読み込み
    Set objDocument = objWordApp.Documents.Open( strInFile )
    
    ' リンク画像→埋め込み画像変換
    EmbedImages objDocument
    
    ' 出力ファイル名作成
    strTimestamp = EvernoteTimeStamp( objDocument, "(?:作成|更新)日" )
    If strTimestamp <> "" Then
        strTimestamp = strTimestamp & "-"
    End If
    strOutFile = objFSO.BuildPath( objFSO.GetParentFolderName( strInFile ), strTimeStamp & objFSO.GetBaseName( strInFile ) & ".docx" )
    
    ' Word ファイル出力
    objDocument.SaveAs strOutFile, wdFormatXMLDocument
    
    objDocument.Close
    
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
