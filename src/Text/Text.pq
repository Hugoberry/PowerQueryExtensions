section Text;

///////////////////////// 
// Text                //
/////////////////////////
shared Text.Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
shared Text.AlphaNumeric = Text.Alphabet & "0123456789";
shared Text.FromList = (list as list) => List.Accumulate(list, "", (state, current) => state & Text.From(current));
// Is text all uppercase? returns false if any non-alpha characters are present
shared Text.IsUpperCase = (text as text) => List.AllTrue(List.Transform(Text.ToList(text), (letter)=>Text.Contains(Text.Alphabet, letter) and letter = Text.Upper(letter)));
shared Text.IsAlpha = (text as text) => List.MatchesAll(Text.ToList(text), each Text.Contains(Text.Alphabet, _));
shared Text.RemoveExtraWhitespace = (text as text) => Text.Combine(Splitter.SplitTextByWhitespace()(text)," "); 
// Splits camelCased and PascalCased text and separates by a space. Ex: "thisIsAColumn" -> "this Is A Column"
shared Text.SplitCamelCase = (text as nullable text) => if text is null then null else List.Accumulate(Text.ToList(text),"", (state, current) => 
   let
      PreviousLetter = Text.End(state, 1),
      Ignore = (text as text) => text = " " or text = "."
   in 
      state & 
      (if 
         not Text.IsUpperCase(PreviousLetter) and 
         not Ignore(PreviousLetter) and 
         not Ignore(current) and 
         Text.IsUpperCase(current) 
       then 
         " " else "" ) & 
      current);
shared Text.SplitOnNotIn = (line as nullable text, validCharacters as text) => Splitter.SplitTextByNotIn(validCharacters)(line);
shared Text.SplitOnNonAlpha = (line as nullable text) =>
  if line is null then null else List.Accumulate(Text.ToList(line), {null} , (state, current) => 
    let
      doSkip = not Text.Contains(Text.Alphabet, current),
      lastItem = List.Last(state),
      appendLast = lastItem<>null
    in
      if doSkip then 
        if lastItem is null then 
          state 
        else 
          List.Combine({state, {null}})
      else
        if appendLast then
          List.Combine({List.RemoveLastN(state, 1), {lastItem & current}})
        else  
          List.Combine({List.RemoveLastN(state, 1), {current}}));
shared Text.Substring = (text as text, start as number, optional count as number) => 
   let 
      start = if start >= 0 then start else error "start index should be >= 0",
      end = if count = null then Text.Length(text) else if count <= Text.Length(text) then count else error "count should be <= text length",
      textList = Text.ToList(text),
      substr = Text.FromList(List.FirstN(List.Skip(textList, start), end - start))
   in substr;
shared Text.IsNumber = (text as text) => try Number.FromText(text) is number otherwise false;
shared Text.PositionAfter = (text as nullable text, substring as text) => 
    let 
        firstIndex = Text.PositionOf(text, substring),
        indexAfter = if firstIndex >=0 then firstIndex + Text.Length(substring) else -1
    in
        if text is null then -1 else if indexAfter >= 0 and indexAfter < Text.Length(text) then indexAfter else -1;
shared Text.Until = (text as text, endDelimiter as text, optional startIndex as number) => 
    let
        start = if startIndex = null then 0 else startIndex,
        textFromStart = Text.Substring(text, start),
        delimPosition = if Text.PositionOf(textFromStart, endDelimiter) >= 0 then Text.PositionOf(textFromStart, endDelimiter) else Text.Length(textFromStart)
    in
        if text is null then null else Text.Range(textFromStart, 0, delimPosition);
shared Text.AsciiOnly = (s as text) as text =>
        let
	        Listified = Text.ToList(s),
	        Numbered = List.Transform(Listified, each Character.ToNumber(_)),
	        Filtered = List.Select(Numbered, each _ <= 255),
	        Stringified = List.Transform(Filtered, each Character.FromNumber(_)),
	        Joined = Text.Combine(Stringified, ""),
	        Return = Joined
        in
	        Return;

shared Text.Between = (Haystack as text, After as text, Before as text) as text =>
let
    CutAfter = Text.Split(Haystack, After),
    CutBefore = Text.Split(CutAfter{1}, Before),
    Needle = if List.Count(CutAfter) > 1
       then (if List.Count(CutBefore) > 1 then CutBefore{0} else Error.Record("FindTextFailed","The text did not contain the keyword " & Before, Haystack))
       else error Error.Record("FindTextFailed","The text did not contain the keyword " & After, Haystack)
in Needle;

shared Text.ContainsAny = (str as text, needles as list) as logical =>
    let
	    count = List.Count(needles)
    in

    List.AnyTrue(
	    List.Generate(
		    ()=>[i=0],
		    each [i] < count,
		    each [i=[i]+1],
		    each Text.Contains(str,needles{[i]})
	    )
    );

shared Text.Count = (Haystack as text, Needle as text) as number =>
    List.Count(Text.Split(Haystack, Needle)) - 1;

shared Text.EachBetween = (Haystack as text, After as text, Before as text) as list =>
    let
        CutAfter = Text.Split(Haystack, After),
	    SkipFirst = List.Skip(CutAfter),
        CutEach = List.Transform(SkipFirst, each Text.Split(_, Before){0})
    in 
        CutEach;

shared Text.EachFromTo = 
    (Haystack as text, After as text, Before as text) as text =>
    let
        CutAfter = Text.Split(Haystack, After),
	    SkipFirst = List.Skip(CutAfter),
        CutEach = List.Transform(SkipFirst, each After & Text.Split(_, Before){0} & Before)
    in 
        CutEach;

shared Text.FromTo = 
(Haystack as text, From as text, UpTo as text) as text =>
let
    CutAfter = Text.Split(Haystack, From),
    CutBefore = Text.Split(CutAfter{1}, UpTo),
    Needle = if List.Count(CutAfter) > 1
       then (if List.Count(CutBefore) > 1 then From & CutBefore{0} & UpTo else Error.Record("FindTextFailed","The text did not contain the keyword " & UpTo, Haystack))
       else error Error.Record("FindTextFailed","The text did not contain the keyword " & From, Haystack)
in Needle;

shared Text.Like = (Phrase as text, Pattern as text) as logical =>
//Originally written by Chris Webb: https://cwebbbi.wordpress.com/2014/05/27/implementing-a-basic-likewildcard-search-function-in-power-query/
let
    //Split pattern up into a list using % as a delimiter
    PatternList = Text.Split(Pattern, "%"),
    //if the first character in the pattern is % then the first item in the list is an empty string
    StartsWithWc = (List.First(PatternList)=""),
    //if the last character in the pattern is % then the last item in the list is an empty string
    EndsWithWc = (List.Last(PatternList)=""),
    //if the first character is not % then we have to match the first string in the pattern with the opening characters of the phrase
    StartsTest = if (StartsWithWc=false) 
       then Text.StartsWith(Phrase, List.First(PatternList)) 
       else true,
    //if the last item is not % then we have to match the final string in the pattern with the final characters of the phrase
    EndsText = if (EndsWithWc=false) 
       then Text.EndsWith(Phrase, List.Last(PatternList)) 
       else true,
    //now we also need to check that each string in the pattern appears in the correct order in the phrase and to do this we need to declare a function PhraseFind
    PhraseFind = (Phrase as text, SearchString as list) =>
    let
     //does the first string in the pattern appear in the phrase?
     StringPos = Text.PositionOf(Phrase, SearchString{0}, Occurrence.First),
     PhraseFindOutput = 
		 if
		 //if string not find then return false 
		 (StringPos=-1) 
		 then false 
		 else if
		 //we have found the string in the pattern, and if this is the last string in the pattern, return true
		 List.Count(SearchString)=1
		 then true
		 else
		 //if it isn't the last string in the pattern test the next string in the pattern by removing the first string from the pattern list and all text up to and including the string we have found in the phrase
		 (true and
		 @PhraseFind(
		 Text.RemoveRange(Phrase, 0, StringPos + Text.Length(SearchString{0})),
		 List.RemoveRange(SearchString, 0, 1)))
     in
      PhraseFindOutput,
    //return true if we have passed all tests    
    Output = StartsTest and EndsText and PhraseFind(Phrase, PatternList) 
in
    Output;

shared Text.PowerTrim = 
//Original is taked from Ken Puls's blog http://www.excelguru.ca/blog/2015/10/08/clean-whitespace-in-powerquery/
(text as text, optional char_to_trim as text) =>
	 let
		 char = if char_to_trim = null then " " else char_to_trim,
		 split = Text.Split(text, char),
		 removeblanks = List.Select(split, each _ <> ""),
		 result=Text.Combine(removeblanks, char)
	 in
 result;

shared Text.RemoveSymbols = 
//Originally written by Chris Webb: https://cwebbbi.wordpress.com/2014/08/18/removing-punctuation-from-text-in-power-query/
(inputtext as text) as text =>
let
    //get a list of lists containing the numbers of Unicode punctuation characters
    numberlists = {{0..31},{33..47},{58..64},{91..96},{123..191}},
    //turn this into a single list
    combinedlist = List.Combine(numberlists),
    //get a list of all the punctuation characters that these numbers represent
    punctuationlist = List.Transform(combinedlist, each Character.FromNumber(_)),
    //some text to test this on
    //inputtext = "Hello! My name is Chris, and I'm hoping that this *cool* post will help you!",
    //the text with punctuation removed
    outputtext = Text.Remove(inputtext, punctuationlist)
in
    outputtext;

shared Text.ReplaceAll =
    (str as text, Replacements as list) as text =>
    let
	    count = List.Count(Replacements)
    in
    List.Last(
	    List.Generate(
		    ()=>[i=0, s=str],
		    each [i] <= count,
		    each [
			    s=Text.Replace([s],Replacements{[i]}{0},Replacements{[i]}{1}),
			    i=[i]+1
		    ],
		    each [s]
	    )
    );


///////////////////////// 
// Dependencies        //
/////////////////////////


Splitter.SplitTextByNotIn = (safeCharacters as text) => (line as nullable text) =>
        if line is null then 
            {} 
        else
            List.Accumulate(Text.ToList(line), {null} , (state, current) => 
            let
                doSkip = not Text.Contains(safeCharacters, current),
                lastItem = List.Last(state),
                appendLast = lastItem<>null
            in
                if doSkip then 
                    if lastItem is null then 
                        state 
                    else 
                      List.Combine({state, {null}})
                else if appendLast then
                    List.Combine({List.RemoveLastN(state, 1), {lastItem & current}})
                else  
                    List.Combine({List.RemoveLastN(state, 1), {current}}));