'use client';

import { MEDIA_BUCKET, supabase } from './supabase';

/** رفع صورة إلى Storage في مسار stores/<store_id>/ (سياسة media_write) */
export async function uploadImage(storeId: string, file: File): Promise<string> {
  if (file.size > 5 * 1024 * 1024) throw new Error('حجم الصورة أكبر من 5 ميجا');
  const ext = file.name.split('.').pop()?.toLowerCase() || 'jpg';
  const path = `stores/${storeId}/${crypto.randomUUID()}.${ext}`;
  const { error } = await supabase().storage.from(MEDIA_BUCKET).upload(path, file, { contentType: file.type, upsert: false });
  if (error) throw error;
  return supabase().storage.from(MEDIA_BUCKET).getPublicUrl(path).data.publicUrl;
}
