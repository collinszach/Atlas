export interface Photo {
  id: string;
  user_id: string;
  transport_leg_id: string;
  storage_key: string;
  thumbnail_key: string | null;
  original_filename: string | null;
  caption: string | null;
  taken_at: string | null;
  latitude: number | null;
  longitude: number | null;
  width: number | null;
  height: number | null;
  size_bytes: number | null;
  is_cover: boolean;
  order_index: number | null;
  url: string;
  thumbnail_url: string | null;
  created_at: string;
}

export interface PhotoListResponse {
  items: Photo[];
  total: number;
}

export interface TransportLeg {
  id: string;
  user_id: string;
  flight_number: string | null;
  airline: string | null;
  origin_iata: string | null;
  dest_iata: string | null;
  origin_city: string | null;
  dest_city: string | null;
  departure_at: string | null;
  arrival_at: string | null;
  duration_min: number | null;
  distance_km: number | null;
  seat_class: string | null;
  booking_ref: string | null;
  cost: number | null;
  currency: string;
  notes: string | null;
  origin_lat: number | null;
  origin_lng: number | null;
  dest_lat: number | null;
  dest_lng: number | null;
  created_at: string;
}

export interface MapArc {
  id: string;
  flight_number: string | null;
  origin_city: string | null;
  dest_city: string | null;
  origin_iata: string | null;
  dest_iata: string | null;
  departure_at: string | null;
  origin_lat: number;
  origin_lng: number;
  dest_lat: number;
  dest_lng: number;
}

export interface EnrichFlightResponse {
  flight_number?: string;
  airline?: string;
  origin_iata?: string;
  dest_iata?: string;
  origin_city?: string;
  dest_city?: string;
  departure_at?: string;
  arrival_at?: string;
  duration_min?: number;
  distance_km?: number;
}

export interface UserStats {
  flights_count: number;
  total_distance_km: number;
  co2_kg_estimate: number;
  hours_in_air: number | null;
  top_airline: string | null;
  most_flown_airport: string | null;
}
