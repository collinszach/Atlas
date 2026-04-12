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
  created_at: string;
  url: string;
  thumbnail_url: string | null;
}

export interface PhotoListResponse {
  items: Photo[];
  total: number;
}
