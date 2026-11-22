import React from 'react';
import { AnimatePresence, motion, useReducedMotion } from 'motion/react';
import { AlertTriangle, CheckCircle2, Info, X, XCircle } from 'lucide-react';

export type ToastVariant = 'success' | 'error' | 'info' | 'warning';

export interface ToastItem {
  id: string;
  title: string;
  message?: string;
  variant: ToastVariant;
  actionLabel?: string;
  onAction?: () => void;
}

export interface ToastContainerProps {
  toasts: ToastItem[];
  onDismiss: (id: string) => void;
}

const variantStyles: Record<
  ToastVariant,
  {
    container: string;
    iconColor: string;
    Icon: React.ComponentType<{ className?: string }>;
  }
> = {
  success: {
    container:
      'border-emerald-300 dark:border-emerald-800/80 bg-white dark:bg-[#0A1F44]',
    iconColor: 'text-emerald-600 dark:text-emerald-400',
    Icon: CheckCircle2,
  },
  error: {
    container: 'border-red-300 dark:border-red-900/80 bg-white dark:bg-[#0A1F44]',
    iconColor: 'text-red-600 dark:text-red-400',
    Icon: XCircle,
  },
  warning: {
    container:
      'border-amber-300 dark:border-amber-800/80 bg-white dark:bg-[#0A1F44]',
    iconColor: 'text-amber-600 dark:text-[#F59E0B]',
    Icon: AlertTriangle,
  },
  info: {
    container: 'border-[#C5A059]/45 dark:border-[#C5A059]/45 bg-white dark:bg-[#0A1F44]',
    iconColor: 'text-[#007AFF] dark:text-[#66B2FF]',
    Icon: Info,
  },
};

export function ToastContainer({ toasts, onDismiss }: ToastContainerProps) {
  const prefersReducedMotion = useReducedMotion();

  if (toasts.length === 0) return null;

  return (
    <div
      role="region"
      aria-label="Notifications"
      aria-live="polite"
      className="fixed top-16 right-4 left-4 sm:left-auto sm:w-96 z-50 flex flex-col gap-2 pointer-events-none"
    >
      <AnimatePresence initial={false}>
        {toasts.slice(0, 3).map((toast) => {
          const style = variantStyles[toast.variant];
          const Icon = style.Icon;
          return (
            <motion.div
              key={toast.id}
              role={toast.variant === 'error' ? 'alert' : 'status'}
              initial={prefersReducedMotion ? { opacity: 1 } : { opacity: 0, y: -12, scale: 0.97 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={prefersReducedMotion ? { opacity: 0 } : { opacity: 0, y: -8, scale: 0.97 }}
              transition={{ duration: 0.18, ease: [0.16, 1, 0.3, 1] }}
              className={`pointer-events-auto rounded-2xl border p-3.5 shadow-lg flex items-start gap-3 ${style.container}`}
            >
              <Icon className={`w-5 h-5 shrink-0 mt-0.5 ${style.iconColor}`} />
              <div className="flex-1 min-w-0">
                <p className="text-xs font-bold text-[#0A1F44] dark:text-white leading-snug">
                  {toast.title}
                </p>
                {toast.message && (
                  <p className="mt-0.5 text-xs text-[#4A5E7A] dark:text-[#93C5FD] leading-snug break-words">
                    {toast.message}
                  </p>
                )}
                {toast.actionLabel && toast.onAction && (
                  <button
                    type="button"
                    onClick={() => {
                      toast.onAction?.();
                      onDismiss(toast.id);
                    }}
                    className="mt-1.5 text-xs font-semibold text-[#007AFF] dark:text-[#E4C788] hover:underline cursor-pointer"
                  >
                    {toast.actionLabel}
                  </button>
                )}
              </div>
              <button
                type="button"
                onClick={() => onDismiss(toast.id)}
                aria-label="Dismiss notification"
                className="p-1.5 rounded-lg text-[#4A5E7A] hover:text-[#0A1F44] dark:text-[#93C5FD] dark:hover:text-white cursor-pointer shrink-0"
              >
                <X className="w-4 h-4" />
              </button>
            </motion.div>
          );
        })}
      </AnimatePresence>
    </div>
  );
}
