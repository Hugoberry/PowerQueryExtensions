section Date;
///////////////////////// 
// Date                //
/////////////////////////
// Basic calendar
shared Date.Calendar =
   Document(
        "Date.Calendar",
        "Generate a calendar table for a given date span - can be text or proper dates. Current columns are Date, DayOfWeek, Month, MonthNum, WeekStartData, WeekStart, Year, YearMonth",
        {[ Description = "2016 calendar", Code ="PBI[Date.Calendar](""1/1/2016"", ""12/31/2016""", Result = "2016 calendar"]},
        (start as any, end as any) => 
            let
                StartDate = Date.From(start),
                EndDate = Date.From(end),
                Source = Date.DatesBetween(StartDate, EndDate),
                FromList = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                Date = Table.RenameColumns(FromList,{{"Column1", "Date"}}),
                DayOfWeek = Table.AddColumn(Date, "Day of Week", each Date.DayName([Date])),
                Month = Table.AddColumn(DayOfWeek, "Month", each Date.MonthName([Date])),
                MonthNum = Table.AddColumn(Month, "MonthNumber", each Date.Month([Date])),
                WeekStartDate = Table.AddColumn(MonthNum, "WeekStartDate", each Date.StartOfWeek([Date])),
                WeekStart = Table.AddColumn(WeekStartDate, "Week Start", each [Month] & " " & Text.From(Date.Day([WeekStartDate]))),
                Year = Table.AddColumn(WeekStart, "Year", each Date.Year([Date])),
                YearMonth = Table.AddColumn(Year, "YearMonth", each Number.From(Text.From([Year]) & (if [MonthNumber] < 10 then "0" else "") & Text.From([MonthNumber]))),
                Result = YearMonth
           in
                Result
    );
shared Date.DatesBetween = Document(
    "Date.DatesBetween",
    "Returns a list of dates in a given span (inclusive). Start and end parameters can be any order",
    {[Description = "Date range", Code = "PBI[Date.DatesBetween](""1/1/2016"", ""1/3/2016"")", Result="{""1/1/2016"", ""1/2/2016"", ""1/3/2016""}" ]},
    (start as any, end as any) => 
      let 
        StartDate = Date.From(start), 
        EndDate = Date.From(end),
        adjustedStart = List.Min({StartDate, EndDate}),
        adjustedEnd = List.Max({StartDate, EndDate}),
        GetDates = (start as date, end as date, dates as list)=> if start > end then dates else @GetDates(Date.AddDays(start, 1), end, List.Combine({dates, {start}})),
        Dates = GetDates(adjustedStart, adjustedEnd, {})
      in Dates
);

shared Date.DayName = Document(
    "Date.DayName",
    "Returns the English day of the week name for a date",
    {[ Description = "Get the day name", Code="Date.DayName(""9/9/2016"")", Result="Friday"]},
    (date as any) => Switch(Date.DayOfWeek(DateTime.From(date)), {0, 1, 2, 3, 4, 5, 6}, {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}, null)
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

Switch = 
    Document(
        "Switch", 
        "Given a value, find it's paired item <br>"&
            "Switch(value as any, cases as list, results as list, optional default as any) <br>" &
            "Switch(value as any, pairs as list, optional default as any)",
        { 
            [ Description = "Using separate lists", Code = "Switch(1, {1, 2, 3}, {""A"", ""B"", ""C""})", Result = "A"],
            [ Description = "Using one paired list", Code = "Switch(1, {{1, ""A""}, {2, ""B""}, {3, ""C""}})", Result = "A"]
        },
        (value as any, casesOrPairs as list, optional resultsOrDefault as any, optional default as any) =>
            let
               hasPairs = List.First(casesOrPairs) is list,
               usingPairs = 
                   let
                       targetPosition = List.PositionOf(casesOrPairs, value, Occurrence.First, (case, theValue) => theValue = case{0})
                   in
                       if targetPosition = -1 then resultsOrDefault else casesOrPairs{targetPosition}{1},
               usingCases = 
                   let
                       cases = casesOrPairs,
                       results = resultsOrDefault
                   in
                       if List.IsEmpty(cases) or List.IsEmpty(results) then default else if value = List.First(cases) then List.First(results) else @Switch(value, List.Skip(cases, 1), List.Skip(results, 1), default)
            in
                if hasPairs then usingPairs else usingCases
    );