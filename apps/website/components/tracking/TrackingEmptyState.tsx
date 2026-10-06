import { ShieldAlert, KeyRound, Share2 } from 'lucide-react';
import { TRACKING_SECURITY_NOTICE } from '@/lib/data/stages';

export function TrackingEmptyState() {
  return (
    <div className="space-y-6">
      {/* ── Privacy & Status Model Notice ─────────────────────────── */}
      <div className="p-5 bg-surface-subtle rounded-2xl border border-border space-y-2">
        <div className="flex items-center gap-2 font-bold text-xs text-cerelo-navy">
          <ShieldAlert className="w-4 h-4 text-cerelo-orange shrink-0" aria-hidden="true" />
          <span>{TRACKING_SECURITY_NOTICE.title}</span>
        </div>
        <p className="text-xs text-text-secondary leading-relaxed">
          {TRACKING_SECURITY_NOTICE.summary}
        </p>
      </div>

      {/* ── Help Guide Cards ──────────────────────────────────────── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
        <div className="p-5 bg-surface-white rounded-xl border border-border space-y-2">
          <div className="flex items-center gap-2 font-bold text-cerelo-navy">
            <KeyRound className="w-4 h-4 text-cerelo-orange shrink-0" aria-hidden="true" />
            <span>Where to Find Your Code</span>
          </div>
          <p className="text-text-secondary leading-relaxed">
            Your Delivery Code (e.g. <span className="font-mono font-medium text-cerelo-navy">CRL-XXXX-XXXX</span>) is issued when CERELO Personnel collects your package and is displayed in your active app shipment view.
          </p>
        </div>

        <div className="p-5 bg-surface-white rounded-xl border border-border space-y-2">
          <div className="flex items-center gap-2 font-bold text-cerelo-navy">
            <Share2 className="w-4 h-4 text-cerelo-orange shrink-0" aria-hidden="true" />
            <span>Shared Tracking Links</span>
          </div>
          <p className="text-text-secondary leading-relaxed">
            If a sender shared a link with you, opening that URL loads your shipment status automatically without needing to type a code manually.
          </p>
        </div>
      </div>
    </div>
  );
}
