import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: {
    template: '%s | Cerelo Admin',
    default: 'Cerelo Admin Panel',
  },
  description: 'Cerelo Operations Management — Intercity Parcel Delivery, Kano ↔ Katsina',
  robots: {
    index: false, // Admin panel must not be publicly indexed
    follow: false,
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
