export interface Trip {
  id: string;
  user_id: string;
  title: string;
  description: string | null;
  status: "past" | "active" | "planned" | "dream";
  start_date: string | null;
  end_date: string | null;
  tags: string[];
  visibility: "private" | "shared" | "public";
  created_at: string;
  updated_at: string;
}

export interface TripListResponse {
  items: Trip[];
  total: number;
  page: number;
  limit: number;
}

export interface Destination {
  id: string;
  trip_id: string;
  user_id: string;
  city: string;
  country_code: string;
  country_name: string;
  region: string | null;
  latitude: number | null;
  longitude: number | null;
  arrival_date: string | null;
  departure_date: string | null;
  nights: number | null;
  notes: string | null;
  rating: number | null;
  order_index: number;
  created_at: string;
}

export interface MapCountry {
  country_code: string;
  country_name: string;
  visit_count: number;
  first_visit: string | null;
  last_visit: string | null;
  total_nights: number;
  trip_ids: string[];
}

export interface MapCity {
  id: string;
  city: string;
  country_code: string;
  country_name: string;
  latitude: number;
  longitude: number;
  arrival_date: string | null;
  departure_date: string | null;
  trip_id: string;
}

export interface Photo {
  id: string;
  user_id: string;
  trip_id: string;
  destination_id: string | null;
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
  page: number;
  limit: number;
}

export interface TransportLeg {
  id: string;
  trip_id: string;
  user_id: string;
  type: "flight" | "car" | "train" | "ferry" | "bus" | "walk" | "other";
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

export interface Accommodation {
  id: string;
  trip_id: string;
  user_id: string;
  destination_id: string | null;
  name: string;
  type: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  check_in: string | null;
  check_out: string | null;
  confirmation: string | null;
  cost_per_night: number | null;
  currency: string;
  rating: number | null;
  notes: string | null;
  created_at: string;
}

export interface MapArc {
  id: string;
  trip_id: string;
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

export interface BucketListItem {
  id: string;
  user_id: string;
  country_code: string | null;
  country_name: string | null;
  city: string | null;
  priority: number;
  reason: string | null;
  ideal_season: string | null;
  estimated_cost: number | null;
  trip_id: string | null;
  ai_summary: string | null;
  created_at: string;
}

export interface BucketListCreate {
  country_code?: string | null;
  country_name?: string | null;
  city?: string | null;
  priority?: number;
  reason?: string | null;
  ideal_season?: string | null;
  estimated_cost?: number | null;
  trip_id?: string | null;
}

export type BucketListUpdate = BucketListCreate;

export interface PlannedCity {
  id: string;
  city: string;
  country_code: string;
  country_name: string;
  latitude: number;
  longitude: number;
  trip_id: string;
  trip_title: string;
}

export interface MonthlyClimate {
  month: number;
  avg_max_temp_c: number;
  avg_precipitation_mm: number;
}

export interface BestTimeResponse {
  location: string;
  latitude: number;
  longitude: number;
  monthly: MonthlyClimate[];
  best_months: number[];
}
