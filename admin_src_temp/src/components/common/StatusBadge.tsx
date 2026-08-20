import React from 'react';

interface StatusBadgeProps {
  status: string;
  className?: string;
}

export const StatusBadge: React.FC<StatusBadgeProps> = ({ status, className = '' }) => {
  const s = (status || '').toLowerCase().trim();

  let bg = 'bg-slate-100 text-slate-700 border-slate-200';
  let dot = 'bg-slate-500';

  if (s === 'confirmed' || s === 'approved' || s === 'active' || s === 'completed' || s === 'resolved' || s === 'processed') {
    bg = 'bg-emerald-50 text-emerald-700 border-emerald-200';
    dot = 'bg-emerald-500';
  } else if (s === 'upcoming' || s === 'in-progress' || s === 'in_progress' || s === 'pending' || s === 'open') {
    bg = 'bg-amber-50 text-amber-700 border-amber-200';
    dot = 'bg-amber-500';
  } else if (s === 'cancelled' || s === 'rejected' || s === 'suspended' || s === 'closed' || s === 'urgent') {
    bg = 'bg-rose-50 text-rose-700 border-rose-200';
    dot = 'bg-rose-500';
  } else if (s === 'hourly' || s === 'car' || s === 'partner') {
    bg = 'bg-purple-50 text-purple-700 border-purple-200';
    dot = 'bg-purple-500';
  } else if (s === 'daily' || s === 'bike' || s === 'user') {
    bg = 'bg-indigo-50 text-indigo-700 border-indigo-200';
    dot = 'bg-indigo-500';
  }

  const formatText = (text: string) => {
    if (!text) return 'UNKNOWN';
    return text.replace(/_/g, ' ').toUpperCase();
  };

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border ${bg} ${className}`}
    >
      <span className={`w-1.5 h-1.5 rounded-full ${dot}`} />
      {formatText(status)}
    </span>
  );
};
