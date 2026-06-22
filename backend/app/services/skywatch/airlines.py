"""ICAO airline designator → operator name.

Used to (a) display the real operator for a callsign (JBU1354 → "JetBlue Airways")
and (b) guard against classifying scheduled commercial flights as military.

Covers the major global, US, low-cost, regional, and cargo operators — i.e. the
overwhelming majority of callsigns a user will see overhead. Extensible.
"""

from __future__ import annotations

import re

AIRLINES: dict[str, str] = {
    # US majors / low-cost
    "AAL": "American Airlines", "UAL": "United Airlines", "DAL": "Delta Air Lines",
    "SWA": "Southwest Airlines", "JBU": "JetBlue Airways", "ASA": "Alaska Airlines",
    "NKS": "Spirit Airlines", "FFT": "Frontier Airlines", "AAY": "Allegiant Air",
    "HAL": "Hawaiian Airlines", "SCX": "Sun Country Airlines", "VXP": "Avelo Airlines",
    "BRO": "Breeze Airways",
    # US regional
    "SKW": "SkyWest Airlines", "RPA": "Republic Airways", "EDV": "Endeavor Air",
    "ENY": "Envoy Air", "ASH": "Mesa Airlines", "PDT": "Piedmont Airlines",
    "JIA": "PSA Airlines", "GJS": "GoJet Airlines", "QXE": "Horizon Air",
    # Canada / Mexico / LatAm
    "ACA": "Air Canada", "WJA": "WestJet", "JZA": "Air Canada Jazz", "TSC": "Air Transat",
    "AMX": "Aeroméxico", "VOI": "Volaris", "VIV": "Viva Aerobus",
    "LAN": "LATAM Airlines", "TAM": "LATAM Brasil", "GLO": "GOL", "AZU": "Azul",
    "AVA": "Avianca", "CMP": "Copa Airlines", "ARG": "Aerolíneas Argentinas",
    # Europe legacy
    "BAW": "British Airways", "AFR": "Air France", "DLH": "Lufthansa", "KLM": "KLM",
    "IBE": "Iberia", "SWR": "SWISS", "AUA": "Austrian Airlines", "SAS": "SAS",
    "TAP": "TAP Air Portugal", "FIN": "Finnair", "EIN": "Aer Lingus", "AEE": "Aegean",
    "CSA": "Czech Airlines", "LOT": "LOT Polish Airlines", "THY": "Turkish Airlines",
    "VIR": "Virgin Atlantic", "ITY": "ITA Airways",
    # Europe low-cost
    "RYR": "Ryanair", "EZY": "easyJet", "EJU": "easyJet Europe", "WZZ": "Wizz Air",
    "VLG": "Vueling", "EWG": "Eurowings", "NAX": "Norwegian", "TRA": "Transavia",
    "JAF": "TUI fly", "TOM": "TUI Airways",
    # Middle East / Africa
    "UAE": "Emirates", "QTR": "Qatar Airways", "ETD": "Etihad Airways",
    "SVA": "Saudia", "MSR": "EgyptAir", "ELY": "El Al", "RJA": "Royal Jordanian",
    "ETH": "Ethiopian Airlines", "QFA": "Qantas", "RAM": "Royal Air Maroc",
    # Asia / Pacific
    "ANA": "All Nippon Airways", "JAL": "Japan Airlines", "KAL": "Korean Air",
    "AAR": "Asiana Airlines", "CCA": "Air China", "CES": "China Eastern",
    "CSN": "China Southern", "CPA": "Cathay Pacific", "SIA": "Singapore Airlines",
    "THA": "Thai Airways", "AIC": "Air India", "IGO": "IndiGo", "MAS": "Malaysia Airlines",
    "GIA": "Garuda Indonesia", "PAL": "Philippine Airlines", "EVA": "EVA Air",
    "CAL": "China Airlines", "VJC": "VietJet Air", "HVN": "Vietnam Airlines",
    "ANZ": "Air New Zealand", "VOZ": "Virgin Australia", "JST": "Jetstar",
    # Cargo (commercial)
    "FDX": "FedEx Express", "UPS": "UPS Airlines", "GTI": "Atlas Air",
    "CLX": "Cargolux", "GEC": "Lufthansa Cargo", "CKS": "Kalitta Air",
    "ABX": "ABX Air", "BOX": "AeroLogic", "NCA": "Nippon Cargo Airlines",
    "CMB": "Cargolux Italia", "PAC": "Polar Air Cargo", "ATN": "Air Transport Intl",
}

_PREFIX_RE = re.compile(r"^([A-Z]{3})")


def airline_icao(callsign: str | None) -> str | None:
    """Return the leading 3-letter ICAO airline designator of a callsign, if any."""
    if not callsign:
        return None
    m = _PREFIX_RE.match(callsign.strip().upper())
    return m.group(1) if m else None


def resolve_airline(callsign: str | None) -> str | None:
    """Map a callsign to its operator name (JBU1354 → 'JetBlue Airways')."""
    code = airline_icao(callsign)
    return AIRLINES.get(code) if code else None


def is_commercial_airline(callsign: str | None) -> bool:
    """True if the callsign belongs to a known scheduled/cargo commercial operator."""
    code = airline_icao(callsign)
    return code in AIRLINES if code else False
