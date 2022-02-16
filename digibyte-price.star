"""
Applet: DigiByte Price
Summary: Displays the current DigiByte price
Description: Displays the current DigiByte price in one or two fiat currencies and/or in Satoshis. Price data is sourced from Coingecko and updates every 15 minutes.
Author: Olly Stedall @saltedlolly
"""

load("render.star", "render")
load("http.star", "http")
load("encoding/base64.star", "base64")
load("cache.star", "cache")
load("schema.star", "schema")
load("math.star", "math")

DGB_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAAAXNSR0IArs4c6QAAAdVJREFUOE9dVFtSw0AMk4HhLNn0iyPRtB/ciBmSnomfNuUqDMSMLG+yIR+ZPNayJD8MvAwwB5wPee8Gd7gDZvA4wjswTw+2nVcsfxGiosRBAcQjMepj5mM2g5vjTsAmdn0prwvzZwoBrVdmDdpBgSzEf74QsDKCowwEMljIEZOIg+E2OvqT4ToCh1OghAGU2wAB3dFJOILnUdQpoTLfmKRtAPozSenM12R0wdANv/yE6ygq/LplTXY7HjKYYJR4vzyYlSMVRclUodTuFsXJq/ovmQ1h9IOKZfQmiqt7glGipzpDGTwrKHCChdVO7xhnsHJcZH/+YARNrW7zV8nDZBu9RAsCR0ABtRpNKVndK+lLflQpPY3327SXXIasPT1ilRRo+Hxf8PxkYB0Y2J8kt9p4m7JZ3VHOapfI31Ha2uk0k3Eyn72jGogq//EDGR6GzcMcEdDMVA/MH3Us1ISkSnPXLkUaHDOohFF+HoiudkfQroZoDmQkQ5xyBZ6jqBo5xyQaUhe9ksliQYPqNvj+WfDy9rh1Vc6PuQXIbtY69lP4Ki/YO2TYZ1UqwShCrhUmupPNukaaZRENGobWdmjCcmcxMvbSvwWxf2UruAa5XUytHy1AXWx/2vAhVoi8DZsAAAAASUVORK5CYII=
""")

SATS_SYMBOL = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAYAAAAHCAYAAAArkDztAAAAAXNSR0IArs4c6QAAAEJJREFUGFddjsENADEIwxL2nxlXQFv1zq8IxYC1SSAcluiJATr7VCQXM5nWiyH51Eu+htlSLZg8N37Ea5Dg+sq0tAAQLh4KW15wlwAAAABJRU5ErkJggg==
""")

#this list contains the supported fiat currencies
CURRENCY_LIST = {
    "AUD": ["AUD", "aud"],
    "CAD": ["CAD", "cad"],
    "EUR": ["EUR", "eur"],
    "GBP": ["GBP", "gbp"],
    "USD": ["USD", "usd"],
}


DEFAULT_FIRST_CURRENCY = "USD"
DEFAULT_SECOND_CURRENCY = "GBP"
DEFAULT_SHOW_FIRST_CURRENCY = True
DEFAULT_SHOW_SECOND_CURRENCY = False
DEFAULT_SHOW_SATS = True
DEFAULT_SHOW_COUNTRY = False


def get_schema():
    currency_options = [
        schema.Option(display = currency, value = currency)
        for currency in CURRENCY_LIST
    ]

    return schema.Schema(
    version = "1",
    fields = [
        schema.Dropdown(
            id = "first_currency",
            name = "Currency 1",
            desc = "The first fiat currency you wish to display the price in. Default is USD.",
            icon = "circle-dollar",
            default = DEFAULT_FIRST_CURRENCY,
            options = currency_options,
        ),
        schema.Dropdown(
            id = "second_currency",
            name = "Currency 2",
            desc = "The optional second fiat currency you wish to display the price in.",
            icon = "circle-dollar",
            default = DEFAULT_SECOND_CURRENCY,
            options = currency_options,
        ),
        schema.Toggle(
            id = "first_currency_toggle",
            name = "Display Currency 1?",
            desc = "Choose whether to display the first fiat currency price.",
            icon = "toggle-on",
            default = DEFAULT_SHOW_FIRST_CURRENCY,
        ),
        schema.Toggle(
            id = "second_currency_toggle",
            name = "Display Currency 2?",
            desc = "Choose whether to display the second fiat currency.",
            icon = "toggle-on",
            default = DEFAULT_SHOW_SECOND_CURRENCY,
        ),
        schema.Toggle(
            id = "sats_toggle",
            name = "Display SATS?",
            desc = "Choose whether to display the price in Satoshis.",
            icon = "toggle-on",
            default = DEFAULT_SHOW_SATS,
        ),
        schema.Toggle(
            id = "country_toggle",
            name = "Display country?",
            desc = "Choose whether to display the two letter country code next to the price. This can be helpful when displaying to dollar currencies (e.g. USD and AUD).",
            icon = "toggle-on",
            default = DEFAULT_SHOW_COUNTRY,
        ),
    ],
)

def main(config):

    DIGIBYTE_PRICE_URL = "https://api.coingecko.com/api/v3/simple/price?ids=digibyte&vs_currencies=aud%2Ccad%2Ceur%2Cgbp%2Csats%2Cusd"

    first_currency = CURRENCY_LIST.get(config.get("first_currency"))
    second_currency = CURRENCY_LIST.get(config.get("second_currency"))
    first_currency_toggle = config.bool("first_currency_toggle")
    second_currency_toggle = config.bool("second_currency_toggle")
    sats_toggle = config.bool("sats_toggle")
    country_toggle = config.bool("country_toggle")


    # LOOKUP CURRENT PRICES (OR RETRIEVE FROM CACHE)

    # Get current prices from cache
    dgb_price_aud_cached = cache.get("dgb_price_aud")
    dgb_price_cad_cached = cache.get("dgb_price_cad")
    dgb_price_eur_cached = cache.get("dgb_price_eur")
    dgb_price_gbp_cached = cache.get("dgb_price_gbp")
    dgb_price_sats_cached = cache.get("dgb_price_sats")
    dgb_price_usd_cached = cache.get("dgb_price_usd")

    if dgb_price_usd_cached != None:
        print("Hit! Displaying cached data.")
        dgb_price_aud = dgb_price_aud_cached
        dgb_price_cad = dgb_price_cad_cached
        dgb_price_eur = dgb_price_eur_cached
        dgb_price_gbp = dgb_price_gbp_cached
        dgb_price_sats = dgb_price_sats_cached
        dgb_price_usd = dgb_price_usd_cached
    else:
        print("Miss! Calling CoinGecko API.")
        dgbquery = http.get(DIGIBYTE_PRICE_URL)
        if dgbquery.status_code != 200:
            fail("Coingecko request failed with status %d", dgbquery.status_code)

        dgb_price_aud = dgbquery.json()["digibyte"]["aud"]
        dgb_price_cad = dgbquery.json()["digibyte"]["cad"]
        dgb_price_eur = dgbquery.json()["digibyte"]["eur"]
        dgb_price_gbp = dgbquery.json()["digibyte"]["gbp"]
        dgb_price_sats = dgbquery.json()["digibyte"]["sats"]
        dgb_price_usd = dgbquery.json()["digibyte"]["usd"] 

        # Store prices in cache
        cache.set("dgb_price_aud", str(dgb_price_aud), ttl_seconds=14400)
        cache.set("dgb_price_cad", str(dgb_price_cad), ttl_seconds=14400)
        cache.set("dgb_price_eur", str(dgb_price_eur), ttl_seconds=14400)
        cache.set("dgb_price_gbp", str(dgb_price_gbp), ttl_seconds=14400)
        cache.set("dgb_price_sats", str(dgb_price_sats), ttl_seconds=14400)
        cache.set("dgb_price_usd", str(dgb_price_usd), ttl_seconds=14400)


    # Setup first currency price
    if first_currency_toggle:
        if first_currency == "aud":
            first_currency_price = dgb_price_aud
            first_currency_symbol = "$"
            first_currency_country = "AU"
        elif first_currency == "cad":
            first_currency_price = dgb_price_cad
            first_currency_symbol = "$"
            first_currency_country = "CA"
        elif first_currency == "eur":
            first_currency_price = dgb_price_eur
            first_currency_symbol = "€"
            first_currency_country = "EU"
        elif first_currency == "gbp":
            first_currency_price = dgb_price_gbp
            first_currency_symbol = "£"
            first_currency_country = "UK"
        elif first_currency == "USD":
            first_currency_price = dgb_price_usd
            first_currency_symbol = "$"
            first_currency_country = "US"

        # Trim and format price
        first_currency_price = str(int(math.round(first_currency_price * 1000)))
        while len(first_currency_price) < 4:
            first_currency_price = "0" + first_currency_price
        first_currency_price = (first_currency_symbol + first_currency_price[0:-3] + "." + first_currency_price[-3:])  

        if country_toggle:
            display_first_currency_price = render.Row(
                children = [
                    render.Text("%s" % first_currency_price),
                    render.Text("%s" % first_currency_country, font="CG-pixel-3x5-mono"),
                ],
            )
        else:
            display_first_currency_price = render.Text("%s" % first_currency_price)



    # Setup second currency price
    if second_currency_toggle:
        if second_currency == "aud":
            second_currency_price = dgb_price_aud
            second_currency_symbol = "$"
            second_currency_country = "AU"
        elif second_currency == "cad":
            second_currency_price = dgb_price_cad
            second_currency_symbol = "$"
            second_currency_country = "CA"
        elif second_currency == "eur":
            second_currency_price = dgb_price_eur
            second_currency_symbol = "€"
            second_currency_country = "EU"
        elif second_currency == "gbp":
            second_currency_price = dgb_price_gbp
            second_currency_symbol = "£"
            second_currency_country = "UK"
        elif second_currency == "usd":
            second_currency_price = dgb_price_usd
            second_currency_symbol = "$"
            second_currency_country = "US"

        # Trim and format price
        second_currency_price = str(int(math.round(second_currency_price * 1000)))
        while len(second_currency_price) < 4:
            second_currency_price = "0" + second_currency_price
        second_currency_price = (second_currency_symbol + second_currency_price[0:-3] + "." + second_currency_price[-3:])  

        # Display country if toggle is set
        if country_toggle:
            display_second_currency_price = render.Row(
                children = [
                    render.Text("%s" % second_currency_price),
                    render.Text("%s" % second_currency_country, font="CG-pixel-3x5-mono"),
                ],
            )
        else:
            display_second_currency_price = render.Text("%s" % first_currency_price)



    # Setup sats price (trim and format)
    if sats_toggle:
        dgb_price_sats = str(int(math.round(dgb_price_sats * 100)))
        dgb_price_sats = (dgb_price_sats[0:-2] + "." + dgb_price_sats[-2:]) 
        display_sats_price = render.Row(
            children = [
                render.Image(src=SATS_SYMBOL),
                render.Text("%s" % dgb_price_sats),
            ],
        )



    return render.Root(
        child = render.Box(
            render.Row(
                expanded=True,
                main_align="space_evenly",
                cross_align="center",
                children = [
                    render.Image(src=DGB_ICON),

                    # Column to hold pricing text evenly distrubuted accross 1-3 rows
                    render.Column(
                        main_align = "space_evenly",
                        expanded = True,
                        children = [
                            display_first_currency_price,
                            display_second_currency_price,
                            display_sats_price,
                        ],
                    ),
                ],
            ),
        ),
    )




