export type UserRole = 'client' | 'driver' | 'store_owner' | 'admin';

export type OrderStatus =
  | 'pending' | 'accepted' | 'preparing' | 'ready_for_pickup' | 'picked_up'
  | 'on_the_way' | 'delivered' | 'rejected' | 'cancelled';

export type DeliveryStatus =
  | 'assigned' | 'accepted' | 'arrived_at_store' | 'picked_up' | 'on_the_way'
  | 'arrived_at_customer' | 'delivered' | 'failed' | 'cancelled';

export interface Profile {
  id: string;
  role: UserRole;
  full_name: string;
  phone: string | null;
  email: string | null;
  status: 'active' | 'suspended' | 'banned' | 'deleted';
}

export interface Store {
  id: string;
  owner_id: string;
  name: string;
  slug: string;
  description: string | null;
  phone: string | null;
  logo_url: string | null;
  cover_url: string | null;
  address_line: string;
  delivery_radius_km: number;
  commission_rate: number;
  avg_prep_time_minutes: number;
  min_order_amount: number;
  delivery_fee_base: number;
  delivery_fee_per_km: number;
  status: 'pending_approval' | 'active' | 'suspended' | 'closed';
  is_open: boolean;
  rating: number;
  rating_count: number;
  created_at: string;
}

export interface Category {
  id: string;
  store_id: string;
  name: string;
  sort_order: number;
  is_active: boolean;
}

export interface Product {
  id: string;
  store_id: string;
  category_id: string | null;
  name: string;
  description: string | null;
  image_url: string | null;
  price: number;
  discounted_price: number | null;
  status: 'active' | 'out_of_stock' | 'hidden' | 'archived';
  prep_time_minutes: number | null;
  calories: number | null;
  sort_order: number;
}

export interface OrderRow {
  id: string;
  order_number: number;
  status: OrderStatus;
  store_id: string;
  subtotal: number;
  delivery_fee: number;
  total_amount: number;
  commission_amount: number;
  store_payout: number;
  payment_method: 'cash' | 'card' | 'wallet';
  payment_status: string;
  placed_at: string;
  customer_notes: string | null;
  estimated_prep_minutes: number | null;
  stores?: { name: string } | null;
  order_items?: { quantity: number; product_name: string; notes: string | null }[];
  deliveries?: { id: string; status: DeliveryStatus }[];
}

export interface OrderDetails {
  id: string;
  order_number: number;
  status: OrderStatus;
  subtotal: number;
  delivery_fee: number;
  service_fee: number;
  tax_amount: number;
  discount_amount: number;
  total_amount: number;
  commission_amount: number;
  store_payout: number;
  payment_method: string;
  payment_status: string;
  customer_notes: string | null;
  delivery_address_text: string;
  placed_at: string;
  cancellation_reason: string | null;
  client: { id: string; full_name: string; phone: string | null };
  store: { id: string; name: string; phone: string | null; address_line: string };
  items: { product_name: string; unit_price: number; quantity: number; line_total: number; notes: string | null }[];
  history: { from: OrderStatus | null; to: OrderStatus; note: string | null; at: string }[];
  delivery: {
    id: string; status: DeliveryStatus; driver_name: string; driver_phone: string | null;
    vehicle_type: string; driver_earning: number;
  } | null;
}

export interface DailyPoint { day: string; orders: number; sales?: number; gmv?: number; commission?: number }
