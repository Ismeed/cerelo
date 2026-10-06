'use client';

import { Info, PackageSearch } from 'lucide-react';
import { Button } from './Button';
import { SITE_CONFIG } from '@/lib/config/site';

export function ContactForm() {
  return (
    <div className="space-y-6">
      <div className="p-6 rounded-xl bg-surface-subtle border border-border space-y-4">
        <div className="flex items-start gap-3">
          <Info className="w-5 h-5 text-cerelo-orange shrink-0 mt-0.5" aria-hidden="true" />
          <div className="space-y-2">
            <h3 className="text-sm font-bold text-cerelo-navy">Online Contact Form Launching Soon</h3>
            <p className="text-xs text-text-secondary leading-relaxed">
              Direct web inquiry submission is currently being integrated with our central operations dispatch.
            </p>
          </div>
        </div>

        <div className="border-t border-border pt-4 space-y-3">
          <p className="text-xs text-text-secondary leading-relaxed">
            <strong>Have an active shipment?</strong> You can check real-time milestone updates directly on our tracking portal using your Delivery Code.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 pt-1">
            <Button
              href={SITE_CONFIG.ctaDestinations.trackShipment.href}
              variant="primary"
              size="sm"
            >
              <PackageSearch className="w-4 h-4 mr-1.5" aria-hidden="true" />
              <span>Track Delivery Code</span>
            </Button>
            <Button
              href={SITE_CONFIG.ctaDestinations.sendPackage.href}
              variant="outline"
              size="sm"
            >
              <span>{SITE_CONFIG.ctaDestinations.sendPackage.label}</span>
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
