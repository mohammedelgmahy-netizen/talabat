import type { DeliveryStatus, OrderStatus } from './types';

const money = new Intl.NumberFormat('ar-EG', { style: 'currency', currency: 'EGP', maximumFractionDigits: 2 });
const dateTime = new Intl.DateTimeFormat('ar-EG', { dateStyle: 'medium', timeStyle: 'short' });
const time = new Intl.DateTimeFormat('ar-EG', { timeStyle: 'short' });

export const fmtMoney = (v: number | string | null | undefined) => money.format(Number(v ?? 0));
export const fmtDateTime = (v: string | null | undefined) => (v ? dateTime.format(new Date(v)) : '-');
export const fmtTime = (v: string | null | undefined) => (v ? time.format(new Date(v)) : '-');
export const fmtNum = (v: number | string | null | undefined) => Number(v ?? 0).toLocaleString('ar-EG');

export const orderStatusLabel: Record<OrderStatus, string> = {
  pending: 'جديد',
  accepted: 'مقبول',
  preparing: 'جاري التحضير',
  ready_for_pickup: 'جاهز للاستلام',
  picked_up: 'استلمه السائق',
  on_the_way: 'في الطريق',
  delivered: 'تم التسليم',
  rejected: 'مرفوض',
  cancelled: 'ملغي',
};

export const orderStatusColor: Record<OrderStatus, string> = {
  pending: 'bg-amber-100 text-amber-800',
  accepted: 'bg-sky-100 text-sky-800',
  preparing: 'bg-blue-100 text-blue-800',
  ready_for_pickup: 'bg-indigo-100 text-indigo-800',
  picked_up: 'bg-teal-100 text-teal-800',
  on_the_way: 'bg-teal-100 text-teal-800',
  delivered: 'bg-emerald-100 text-emerald-800',
  rejected: 'bg-rose-100 text-rose-800',
  cancelled: 'bg-gray-200 text-gray-700',
};

export const deliveryStatusLabel: Record<DeliveryStatus, string> = {
  assigned: 'بانتظار قبول السائق',
  accepted: 'السائق في الطريق للمتجر',
  arrived_at_store: 'السائق في المتجر',
  picked_up: 'تم الاستلام',
  on_the_way: 'في الطريق للعميل',
  arrived_at_customer: 'عند العميل',
  delivered: 'تم التسليم',
  failed: 'فشل التسليم',
  cancelled: 'ملغاة',
};

export const paymentLabel: Record<string, string> = { cash: 'كاش', card: 'بطاقة', wallet: 'محفظة' };

export const ACTIVE_ORDER_STATUSES: OrderStatus[] = ['pending', 'accepted', 'preparing', 'ready_for_pickup', 'picked_up', 'on_the_way'];

export const storeStatusLabel: Record<string, string> = {
  pending_approval: 'بانتظار الموافقة',
  active: 'نشط',
  suspended: 'موقوف',
  closed: 'مغلق نهائياً',
};

export const roleLabel: Record<string, string> = { client: 'عميل', driver: 'سائق', store_owner: 'صاحب متجر', admin: 'مدير' };
