from datetime import timedelta, datetime


def parse_duration(duration_str):
   
    #example : P1DT30M13S
    duration_str = duration_str.replace("P", "").replace("T", "")
    #expected : 1D30M13S
    
    components = ["D", "H", "M", "S"]
    values = {"D": 0, "H": 0, "M": 0, "S": 0}

    for component in components:
        if component in duration_str:
            value, duration_str = duration_str.split(component)
            values[component] = int(value)

    total_duration = timedelta(
        days=values["D"], hours=values["H"], minutes=values["M"], seconds=values["S"]
    )

    return total_duration


def transform_data(row):
    # update passed row: convert duration to H:MM:SS and define video type
    duration_td = parse_duration(row["Duration"])

    total_seconds = int(duration_td.total_seconds())
    hours, remainder = divmod(total_seconds, 3600)
    minutes, seconds = divmod(remainder, 60)

    # Format as HH:MM:SS (days collapsed into hours)
    row["Duration"] = f"{hours:02}:{minutes:02}:{seconds:02}"

    # Classify Shorts vs Normal
    row["Video_Type"] = "Shorts" if total_seconds <= 60 else "Normal"

    return row