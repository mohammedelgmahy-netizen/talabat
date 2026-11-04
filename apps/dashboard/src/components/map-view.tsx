'use client';

import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import { useEffect } from 'react';
import { CircleMarker, MapContainer, Marker, Popup, TileLayer, useMap, useMapEvents } from 'react-leaflet';

export interface MapPoint {
  id: string;
  lat: number;
  lng: number;
  color: string;
  label: string;
  emoji?: string;
}

const emojiIcon = (emoji: string) =>
  L.divIcon({
    className: '',
    html: `<div style="font-size:24px;line-height:24px;filter:drop-shadow(0 1px 2px rgba(0,0,0,.4))">${emoji}</div>`,
    iconSize: [24, 24],
    iconAnchor: [12, 12],
  });

function ClickHandler({ onPick }: { onPick?: (lat: number, lng: number) => void }) {
  useMapEvents({ click: (e) => onPick?.(e.latlng.lat, e.latlng.lng) });
  return null;
}

function Recenter({ lat, lng }: { lat: number; lng: number }) {
  const map = useMap();
  useEffect(() => {
    map.setView([lat, lng], map.getZoom());
  }, [lat, lng, map]);
  return null;
}

/** خريطة OpenStreetMap (بدون مفاتيح). تستخدم في الخريطة الحية واختيار موقع المتجر */
export default function MapView({
  center,
  zoom = 12,
  points = [],
  height = 420,
  onPick,
  follow,
}: {
  center: [number, number];
  zoom?: number;
  points?: MapPoint[];
  height?: number;
  onPick?: (lat: number, lng: number) => void;
  follow?: boolean;
}) {
  return (
    <div style={{ height }} className="overflow-hidden rounded-xl border">
      <MapContainer center={center} zoom={zoom} style={{ height: '100%', width: '100%' }} scrollWheelZoom>
        <TileLayer attribution="&copy; OpenStreetMap" url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
        <ClickHandler onPick={onPick} />
        {follow && <Recenter lat={center[0]} lng={center[1]} />}
        {points.map((p) =>
          p.emoji ? (
            <Marker key={p.id} position={[p.lat, p.lng]} icon={emojiIcon(p.emoji)}>
              <Popup>{p.label}</Popup>
            </Marker>
          ) : (
            <CircleMarker key={p.id} center={[p.lat, p.lng]} radius={8} pathOptions={{ color: p.color, fillColor: p.color, fillOpacity: 0.8 }}>
              <Popup>{p.label}</Popup>
            </CircleMarker>
          ),
        )}
      </MapContainer>
    </div>
  );
}
