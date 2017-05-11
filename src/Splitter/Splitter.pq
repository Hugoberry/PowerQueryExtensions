section Splitter;
/////////////////////////
// Splitters           //
/////////////////////////
shared Splitter.SplitTextByNonAlpha = Document(
    "Splitter.SplitTextByNonAlpha",
    "Splits text by characters that aren't [A-Za-z]",
    {[ Description = "Split text", Code="PBI[Splitter.SplitTextByNonAlpha](""A1B,C"")", Result = "{ ""A"", ""B"", ""C"" }"]},
    (line as text) => Splitter.SplitTextByNotIn(Text.Alphabet)
);

shared Splitter.SplitTextByNotIn = Document(
    "Splitter.SplitTextByNotIn",
    "Splits text on any characters that aren't the provided 'safe' characters",
    {[ Description = "Split on non-alphanumeric", Code = "PBI[Splitter.SplitTextByNotIn](PBI[Text.Alphanumeric])(""Power BI is #1"")", Result = "{""Power BI is "", ""1""}"]},
    (safeCharacters as text) => (line as nullable text) =>
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
                    List.Combine({List.RemoveLastN(state, 1), {current}}))
);

/////////////////////////
// Dependencies        //
/////////////////////////
Document = (name as text, description as text, valueOrExample as any, optional valueIfExample as any) =>
    let
        value = if valueIfExample is null then valueOrExample else valueIfExample,
        examples = if valueIfExample is null then {} else valueOrExample
    in
        Value.ReplaceType(value, Value.Type(value) meta [
            Documentation.Name = name, 
            Documentation.Description = description,  
            // [Description = "", Code="", Result =""]
            Documentation.Examples = examples
        ]);
Text.Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";