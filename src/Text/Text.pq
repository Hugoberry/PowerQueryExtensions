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