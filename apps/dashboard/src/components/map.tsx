'use client';

import dynamic from 'next/dynamic';
import { Spinner } from './ui';

/** Leaflet بيحتاج window فبنحمّله في المتصفح فقط */
export const Map = dynamic(() => import('./map-view'), { ssr: false, loading: () => <Spinner label="تحميل الخريطة..." /> });
export type { MapPoint } from './map-view';
