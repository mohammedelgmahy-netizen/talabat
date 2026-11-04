'use client';

import { useState } from 'react';
import { useStore } from '@/components/store-context';
import { Badge, Button, Card, ErrorBox, Field, Input, Modal, PageHeader, Select, Spinner, Table, Td, Textarea } from '@/components/ui';
import { fmtMoney } from '@/lib/format';
import { must, useAction, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';
import type { Category, Product } from '@/lib/types';
import { uploadImage } from '@/lib/upload';

const productStatus: Record<Product['status'], [string, string]> = {
  active: ['متاح', 'bg-emerald-100 text-emerald-800'],
  out_of_stock: ['نفد', 'bg-amber-100 text-amber-800'],
  hidden: ['مخفي', 'bg-gray-100 text-gray-600'],
  archived: ['مؤرشف', 'bg-gray-200 text-gray-500'],
};

export default function MenuPage() {
  const { store } = useStore();
  const [filterCat, setFilterCat] = useState('');
  const [editing, setEditing] = useState<Partial<Product> | null>(null);
  const action = useAction();

  const { data, error, loading, reload } = useLiveQuery<{ categories: Category[]; products: Product[] }>(
    async () => {
      const [c, p] = await Promise.all([
        supabase().from('categories').select('*').eq('store_id', store!.id).order('sort_order'),
        supabase().from('products').select('*').eq('store_id', store!.id).neq('status', 'archived').order('sort_order'),
      ]);
      return { categories: must(c) as Category[], products: must(p) as Product[] };
    },
    [store?.id],
  );

  const addCategory = () => {
    const name = prompt('اسم القسم الجديد');
    if (!name?.trim()) return;
    action.run(async () => {
      must(await supabase().from('categories').insert({ store_id: store!.id, name: name.trim(), sort_order: data?.categories.length ?? 0 }));
      await reload();
    });
  };

  const renameCategory = (c: Category) => {
    const name = prompt('الاسم الجديد', c.name);
    if (!name?.trim() || name === c.name) return;
    action.run(async () => {
      must(await supabase().from('categories').update({ name: name.trim() }).eq('id', c.id));
      await reload();
    });
  };

  const toggleCategory = (c: Category) =>
    action.run(async () => {
      must(await supabase().from('categories').update({ is_active: !c.is_active }).eq('id', c.id));
      await reload();
    });

  const deleteCategory = (c: Category) => {
    if (!confirm(`حذف قسم "${c.name}"؟ المنتجات ستبقى بدون قسم.`)) return;
    action.run(async () => {
      must(await supabase().from('categories').delete().eq('id', c.id));
      await reload();
    });
  };

  const setProductStatus = (p: Product, status: Product['status']) =>
    action.run(async () => {
      must(await supabase().from('products').update({ status }).eq('id', p.id));
      await reload();
    });

  const products = (data?.products ?? []).filter((p) => !filterCat || (filterCat === 'none' ? !p.category_id : p.category_id === filterCat));
  const catName = (id: string | null) => data?.categories.find((c) => c.id === id)?.name ?? '—';

  return (
    <>
      <PageHeader title="المنيو والمنتجات" action={<Button onClick={() => setEditing({ status: 'active', price: 0 })}>+ منتج جديد</Button>} />
      {(error || action.error) && <div className="mb-4"><ErrorBox message={(error || action.error)!} /></div>}
      {loading && !data ? (
        <Spinner />
      ) : (
        <div className="grid gap-6 xl:grid-cols-4">
          <Card title="الأقسام" action={<Button variant="secondary" className="px-2 py-1 text-xs" onClick={addCategory}>+ قسم</Button>}>
            <ul className="space-y-1">
              <li>
                <button onClick={() => setFilterCat('')} className={`w-full rounded-lg px-3 py-2 text-right text-sm ${!filterCat ? 'bg-orange-50 font-bold text-orange-700' : 'hover:bg-gray-50'}`}>
                  كل المنتجات ({data?.products.length})
                </button>
              </li>
              {data?.categories.map((c) => (
                <li key={c.id} className="group flex items-center gap-1">
                  <button
                    onClick={() => setFilterCat(c.id)}
                    className={`flex-1 rounded-lg px-3 py-2 text-right text-sm ${filterCat === c.id ? 'bg-orange-50 font-bold text-orange-700' : 'hover:bg-gray-50'} ${!c.is_active ? 'text-gray-400 line-through' : ''}`}
                  >
                    {c.name}
                  </button>
                  <button title="إعادة تسمية" className="p-1 text-xs" onClick={() => renameCategory(c)}>✏️</button>
                  <button title={c.is_active ? 'إخفاء' : 'إظهار'} className="p-1 text-xs" onClick={() => toggleCategory(c)}>{c.is_active ? '👁️' : '🚫'}</button>
                  <button title="حذف" className="p-1 text-xs" onClick={() => deleteCategory(c)}>🗑️</button>
                </li>
              ))}
              <li>
                <button onClick={() => setFilterCat('none')} className={`w-full rounded-lg px-3 py-2 text-right text-sm ${filterCat === 'none' ? 'bg-orange-50 font-bold text-orange-700' : 'hover:bg-gray-50'}`}>
                  بدون قسم
                </button>
              </li>
            </ul>
          </Card>
          <Card className="xl:col-span-3">
            <Table head={['', 'المنتج', 'القسم', 'السعر', 'الحالة', '']}>
              {products.map((p) => (
                <tr key={p.id} className="hover:bg-gray-50">
                  <Td>
                    {p.image_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={p.image_url} alt="" className="h-12 w-12 rounded-lg object-cover" />
                    ) : (
                      <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-gray-100">🍽️</div>
                    )}
                  </Td>
                  <Td>
                    <div className="font-semibold">{p.name}</div>
                    <div className="max-w-xs truncate text-xs text-gray-500">{p.description}</div>
                  </Td>
                  <Td>{catName(p.category_id)}</Td>
                  <Td>
                    {p.discounted_price != null ? (
                      <>
                        <span className="font-semibold">{fmtMoney(p.discounted_price)}</span>{' '}
                        <span className="text-xs text-gray-400 line-through">{fmtMoney(p.price)}</span>
                      </>
                    ) : (
                      fmtMoney(p.price)
                    )}
                  </Td>
                  <Td>
                    <Badge className={productStatus[p.status][1]}>{productStatus[p.status][0]}</Badge>
                  </Td>
                  <Td>
                    <div className="flex gap-2">
                      <Button variant="secondary" className="px-2 py-1 text-xs" onClick={() => setEditing(p)}>تعديل</Button>
                      {p.status === 'active' ? (
                        <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => setProductStatus(p, 'out_of_stock')}>نفد</Button>
                      ) : (
                        <Button variant="ghost" className="px-2 py-1 text-xs" onClick={() => setProductStatus(p, 'active')}>إتاحة</Button>
                      )}
                      <Button variant="ghost" className="px-2 py-1 text-xs text-rose-600" onClick={() => confirm('أرشفة المنتج؟') && setProductStatus(p, 'archived')}>
                        أرشفة
                      </Button>
                    </div>
                  </Td>
                </tr>
              ))}
            </Table>
            {products.length === 0 && <div className="p-8 text-center text-sm text-gray-400">لا توجد منتجات</div>}
          </Card>
        </div>
      )}
      {editing && store && (
        <ProductModal
          storeId={store.id}
          product={editing}
          categories={data?.categories ?? []}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            reload();
          }}
        />
      )}
    </>
  );
}

function ProductModal({
  storeId,
  product,
  categories,
  onClose,
  onSaved,
}: {
  storeId: string;
  product: Partial<Product>;
  categories: Category[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [form, setForm] = useState<Partial<Product>>(product);
  const { busy, error, run } = useAction();
  const set = <K extends keyof Product>(k: K, v: Product[K] | null) => setForm((f) => ({ ...f, [k]: v }));

  const save = () =>
    run(async () => {
      if (!form.name?.trim()) throw new Error('اسم المنتج مطلوب');
      const payload = {
        store_id: storeId,
        category_id: form.category_id || null,
        name: form.name.trim(),
        description: form.description?.trim() || null,
        image_url: form.image_url || null,
        price: Number(form.price ?? 0),
        discounted_price: form.discounted_price == null || String(form.discounted_price) === '' ? null : Number(form.discounted_price),
        status: form.status ?? 'active',
        prep_time_minutes: form.prep_time_minutes ? Number(form.prep_time_minutes) : null,
        calories: form.calories ? Number(form.calories) : null,
        sort_order: Number(form.sort_order ?? 0),
      };
      if (payload.discounted_price != null && payload.discounted_price >= payload.price) throw new Error('سعر الخصم يجب أن يكون أقل من السعر الأصلي');
      if (form.id) must(await supabase().from('products').update(payload).eq('id', form.id));
      else must(await supabase().from('products').insert(payload));
      onSaved();
    });

  return (
    <Modal open onClose={onClose} title={form.id ? 'تعديل منتج' : 'منتج جديد'} wide>
      <div className="grid gap-4 sm:grid-cols-2">
        {error && <div className="sm:col-span-2"><ErrorBox message={error} /></div>}
        <Field label="اسم المنتج">
          <Input value={form.name ?? ''} onChange={(e) => set('name', e.target.value)} />
        </Field>
        <Field label="القسم">
          <Select value={form.category_id ?? ''} onChange={(e) => set('category_id', e.target.value || null)}>
            <option value="">بدون قسم</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </Select>
        </Field>
        <div className="sm:col-span-2">
          <Field label="الوصف">
            <Textarea rows={2} value={form.description ?? ''} onChange={(e) => set('description', e.target.value)} />
          </Field>
        </div>
        <Field label="السعر (ج.م)">
          <Input type="number" min={0} step={0.5} dir="ltr" value={form.price ?? ''} onChange={(e) => set('price', Number(e.target.value))} />
        </Field>
        <Field label="السعر بعد الخصم (اختياري)">
          <Input
            type="number"
            min={0}
            step={0.5}
            dir="ltr"
            value={form.discounted_price ?? ''}
            onChange={(e) => set('discounted_price', e.target.value === '' ? null : Number(e.target.value))}
          />
        </Field>
        <Field label="الحالة">
          <Select value={form.status} onChange={(e) => set('status', e.target.value as Product['status'])}>
            {Object.entries(productStatus).map(([k, [l]]) => (
              <option key={k} value={k}>{l}</option>
            ))}
          </Select>
        </Field>
        <Field label="وقت التحضير (دقيقة)">
          <Input type="number" min={1} max={240} dir="ltr" value={form.prep_time_minutes ?? ''} onChange={(e) => set('prep_time_minutes', e.target.value ? Number(e.target.value) : null)} />
        </Field>
        <Field label="السعرات (اختياري)">
          <Input type="number" min={0} dir="ltr" value={form.calories ?? ''} onChange={(e) => set('calories', e.target.value ? Number(e.target.value) : null)} />
        </Field>
        <Field label="ترتيب العرض">
          <Input type="number" dir="ltr" value={form.sort_order ?? 0} onChange={(e) => set('sort_order', Number(e.target.value))} />
        </Field>
        <div className="sm:col-span-2">
          <Field label="صورة المنتج" hint="JPG / PNG / WEBP حتى 5 ميجا">
            <div className="flex items-center gap-4">
              {form.image_url && (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={form.image_url} alt="" className="h-20 w-20 rounded-lg object-cover" />
              )}
              <input
                type="file"
                accept="image/jpeg,image/png,image/webp"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) run(async () => set('image_url', await uploadImage(storeId, file)));
                }}
              />
            </div>
          </Field>
        </div>
      </div>
      <div className="mt-6 flex gap-3">
        <Button onClick={save} disabled={busy}>{busy ? '...' : 'حفظ'}</Button>
        <Button variant="secondary" onClick={onClose}>إلغاء</Button>
      </div>
    </Modal>
  );
}
