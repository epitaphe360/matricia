'use client';
import { useState } from 'react';
import { Pause, Play } from 'lucide-react';
import type { Locale } from '@/lib/i18n/locale';
export function MotionControl({ locale }: { locale: Locale }) {
  const [paused, setPaused] = useState(false);
  const label = locale === 'fr'
    ? paused ? 'Reprendre les animations' : 'Mettre les animations en pause'
    : paused ? 'استئناف الحركة' : 'إيقاف الحركة مؤقتاً';
  return <button className="mx-motion-control" aria-label={label} aria-pressed={paused} onClick={event => {
    const root = event.currentTarget.closest('.mx-experience');
    root?.setAttribute('data-motion', paused ? 'running' : 'paused');
    setPaused(!paused);
  }}>{paused ? <Play size={15} aria-hidden="true" /> : <Pause size={15} aria-hidden="true" />}<span>{label}</span></button>;
}
