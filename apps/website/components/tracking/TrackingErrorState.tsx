import { AlertCircle, WifiOff, Search, RotateCcw } from 'lucide-react';
import { Button } from '@/components/ui/Button';

interface TrackingErrorStateProps {
  errorCode: string;
  onRetry: () => void;
}

type ErrorVariant = {
  icon: React.ReactNode;
  title: string;
  message: string;
};

export function TrackingErrorState({ errorCode, onRetry }: TrackingErrorStateProps) {
  const variant = resolveErrorVariant(errorCode);

  return (
    <div className="p-8 sm:p-10 bg-surface-white rounded-2xl border border-border text-center space-y-4 shadow-subtle max-w-lg mx-auto">
      <div className="w-12 h-12 rounded-full bg-status-error-bg border border-status-error/20 text-status-error flex items-center justify-center mx-auto">
        {variant.icon}
      </div>

      <div className="space-y-1.5">
        <h3 className="text-lg font-bold text-cerelo-navy">{variant.title}</h3>
        <p className="text-xs sm:text-sm text-text-secondary leading-relaxed max-w-sm mx-auto">
          {variant.message}
        </p>
      </div>

      <div className="pt-2">
        <Button onClick={onRetry} variant="outline" size="sm">
          <RotateCcw className="w-3.5 h-3.5 mr-1.5" aria-hidden="true" />
          <span>Try Another Code</span>
        </Button>
      </div>
    </div>
  );
}

function resolveErrorVariant(errorCode: string): ErrorVariant {
  // Genuine network failure — no internet or server unreachable
  if (errorCode === 'NETWORK_ERROR') {
    return {
      icon: <WifiOff className="w-6 h-6" aria-hidden="true" />,
      title: 'No Connection',
      message:
        'Could not reach the Cerelo tracking service. Please check your internet connection and try again.',
    };
  }

  // Invalid or expired share token
  if (errorCode === 'INVALID_OR_EXPIRED_TOKEN') {
    return {
      icon: <AlertCircle className="w-6 h-6" aria-hidden="true" />,
      title: 'Invalid or Expired Tracking Link',
      message:
        'This tracking link has expired or been revoked. Please ask the sender for an updated link, or enter your Delivery Code directly.',
    };
  }

  // Delivery Code format doesn't match expected pattern
  if (errorCode === 'INVALID_CREDENTIAL_FORMAT') {
    return {
      icon: <AlertCircle className="w-6 h-6" aria-hidden="true" />,
      title: 'Invalid Code Format',
      message:
        'That doesn\'t look like a valid Delivery Code. CERELO Delivery Codes follow the format CRL-XXXX-XXXX.',
    };
  }

  // Valid format but no matching shipment in the database
  // SHIPMENT_NOT_FOUND or any unrecognised error code
  return {
    icon: <Search className="w-6 h-6" aria-hidden="true" />,
    title: 'Shipment Not Found',
    message:
      'No shipment was found matching this Delivery Code. Please double-check the code and try again. Codes are case-insensitive (e.g. CRL-EXVG-VUSE).',
  };
}

